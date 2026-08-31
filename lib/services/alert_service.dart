import 'db.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import 'location_service.dart';

/// Creates SOS alerts and provides live streams of alert state/history.
class AlertService {
  AlertService({FirebaseFirestore? firestore})
      : _db = firestore ?? mysosDb;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _alerts =>
      _db.collection('alerts');

  /// Create an SOS alert. Location is fetched best-effort in parallel with
  /// a short timeout so it never delays the alert by much.
  Future<DocumentSnapshot<Map<String, dynamic>>> sendSos({
    required Profile profile,
    required String source,
  }) async {
    // Fetch location while we prepare the document — do not await alone.
    final locationFuture = getCurrentPosition();

    final data = <String, dynamic>{
      'userId': profile.uid,
      'userName': profile.displayName ?? 'ผู้ใช้',
      'status': 'active',
      'source': source,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'caregiverUids': profile.caregiverUids,
    };

    final location = await locationFuture;
    if (location != null) {
      data['location'] = {'lat': location.lat, 'lng': location.lng};
    }

    final doc = await _alerts.add(data);
    return doc.get();
  }

  /// Live state of a single alert (delivery status, acks, cancellation).
  Stream<AlertRecord> watchAlert(String alertId) {
    return _alerts.doc(alertId).snapshots().map(AlertRecord.fromSnapshot);
  }

  /// Most recent alerts created by [uid].
  Stream<List<AlertRecord>> watchUserAlerts(String uid, {int limit = 20}) {
    return _alerts
        .where('userId', isEqualTo: uid)
        .orderBy('ts', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AlertRecord.fromSnapshot).toList());
  }

  /// Alerts involving any user this caregiver cares for.
  Stream<List<AlertRecord>> watchCaregiverAlerts(String caregiverUid, {int limit = 30}) {
    return _alerts
        .where('caregiverUids', arrayContains: caregiverUid)
        .orderBy('ts', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AlertRecord.fromSnapshot).toList());
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
