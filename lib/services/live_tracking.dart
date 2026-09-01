import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart';
import 'db.dart';

/// Streams the owner's live GPS into an active alert, for at most
/// [AppConfig.liveLocationWindow] after it fired.
///
/// Each write updates `location` (the position caregivers see), appends a
/// trail point to `locationHistory`, and stamps `locationUpdatedAt`. The
/// tracker stops itself when the alert is acked/cancelled, when the window
/// elapses, or when [stop] is called. It only works while the app is alive
/// (foreground); that is the accepted trade-off — no background location.
class LiveLocationTracker {
  LiveLocationTracker({FirebaseFirestore? firestore})
      : _db = firestore ?? mysosDb;

  final FirebaseFirestore _db;

  StreamSubscription<Position>? _positions;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _alert;
  Timer? _deadline;
  int? _lastSentAt;
  int _trailPoints = 0;
  bool _stopped = true;

  bool get isRunning => !_stopped;

  /// Begin tracking alert [alertId] created at [alertTs] (ms since epoch).
  Future<void> start({required String alertId, required int alertTs}) async {
    if (!_stopped) return;
    _stopped = false;
    _trailPoints = 0;
    _lastSentAt = null;

    // Stop as soon as the alert is no longer active (acked / cancelled).
    _alert = _db.collection('alerts').doc(alertId).snapshots().listen(
      (snap) {
        final status = snap.data()?['status'] as String?;
        if (status != null && status != 'active') stop();
      },
      onError: (e) => debugPrint('[live] alert listener error: $e'),
    );

    final remainingMs = (alertTs + AppConfig.liveLocationWindow.inMilliseconds) -
        DateTime.now().millisecondsSinceEpoch;
    _deadline = Timer(Duration(milliseconds: remainingMs.clamp(0, 1 << 31)), stop);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (_stopped) return; // alert ended while we were asking
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        !await Geolocator.isLocationServiceEnabled()) {
      debugPrint('[live] permission/service unavailable — no live updates');
      return; // the alert already carries its creation-time fix
    }

    _positions = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) => _send(alertId, p));
  }

  Future<void> _send(String alertId, Position p) async {
    if (_stopped) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastSentAt;
    if (last != null && now - last < AppConfig.liveLocationInterval.inMilliseconds) {
      return;
    }
    _lastSentAt = now;

    final appendTrail = _trailPoints < AppConfig.liveLocationMaxPoints;
    try {
      await _db.collection('alerts').doc(alertId).update({
        'location': {'lat': p.latitude, 'lng': p.longitude},
        'locationUpdatedAt': now,
        if (appendTrail)
          'locationHistory': FieldValue.arrayUnion([
            {'lat': p.latitude, 'lng': p.longitude, 'ts': now}
          ]),
      });
      if (appendTrail) _trailPoints++;
    } catch (e) {
      debugPrint('[live] update failed: $e');
    }
  }

  void stop() {
    if (_stopped) return;
    _stopped = true;
    _positions?.cancel();
    _positions = null;
    _alert?.cancel();
    _alert = null;
    _deadline?.cancel();
    _deadline = null;
  }
}
