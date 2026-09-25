import 'dart:math' as math;

import 'db.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import 'location_service.dart';

/// Re-subscribes [factory] forever with backoff when the stream errors out,
/// so a listener that died (network blip, transient permission error) heals
/// instead of leaving the UI stuck on stale data.
Stream<T> _resilient<T>(Stream<T> Function() factory) async* {
  var attempts = 0;
  while (true) {
    try {
      await for (final value in factory()) {
        attempts = 0;
        yield value;
      }
    } catch (e) {
      attempts++;
      debugPrint('[alert] listener dropped, retry #$attempts: $e');
    }
    await Future<void>.delayed(
        Duration(seconds: math.min(2 * attempts, 15)));
  }
}

/// Creates SOS alerts and provides live streams of alert state/history.
class AlertService {
  AlertService({FirebaseFirestore? firestore})
      : _db = firestore ?? mysosDb;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _alerts =>
      _db.collection('alerts');

  /// Create an SOS alert. [location] is an already-resolved (possibly null)
  /// GPS fix — the SOS screen warms one up during its countdown and hands it
  /// over here; the write itself never waits on GPS.
  Future<DocumentSnapshot<Map<String, dynamic>>> sendSos({
    required Profile profile,
    required String source,
    required GpsPosition? location,
  }) async {
    final data = <String, dynamic>{
      'userId': profile.uid,
      'userName': profile.displayName ?? 'ผู้ใช้',
      'status': 'active',
      'source': source,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'caregiverUids': profile.caregiverUids,
    };
    if (location != null) {
      data['location'] = {'lat': location.lat, 'lng': location.lng};
    }

    final doc = await _alerts.add(data);
    return doc.get();
  }

  /// Live state of a single alert (delivery status, acks, cancellation).
  Stream<AlertRecord> watchAlert(String alertId) {
    return _resilient(() =>
        _alerts.doc(alertId).snapshots().map(AlertRecord.fromSnapshot));
  }

  /// Most recent alerts created by [uid] — last 3 days, max [limit] items.
  Stream<List<AlertRecord>> watchUserAlerts(String uid, {int limit = 20}) {
    return _resilient(() {
      final cutoff =
          DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
      return _alerts
          .where('userId', isEqualTo: uid)
          .where('ts', isGreaterThan: cutoff)
          .orderBy('ts', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(AlertRecord.fromSnapshot).toList());
    });
  }

  /// Alerts involving any user this caregiver cares for — last 3 days.
  Stream<List<AlertRecord>> watchCaregiverAlerts(String caregiverUid, {int limit = 30}) {
    return _resilient(() {
      final cutoff =
          DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
      return _alerts
          .where('caregiverUids', arrayContains: caregiverUid)
          .where('ts', isGreaterThan: cutoff)
          .orderBy('ts', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(AlertRecord.fromSnapshot).toList());
    });
  }

  Future<void> cancelAlert(String alertId) async {
    await _alerts.doc(alertId).update({'status': 'cancelled'});
  }

  /// Caregiver acknowledges an active alert.
  Future<void> ackAlert(String alertId, Profile caregiver) async {
    await _alerts.doc(alertId).update({
      'status': 'acked',
      'ackBy': caregiver.uid,
      'ackByName': caregiver.displayName ?? 'ผู้ดูแล',
      'ackAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<AlertRecord?> getAlert(String alertId) async {
    final snap = await _alerts.doc(alertId).get();
    if (!snap.exists) return null;
    return AlertRecord.fromSnapshot(snap);
  }
}
