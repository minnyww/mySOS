import '../services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services/alert_service.dart';
import '../services/bootstrap.dart';
import '../services/pairing_service.dart';

/// Injected from main() after awaiting bootstrap.
final firebaseBootProvider = Provider<BootstrapResult>(
  (_) => throw UnimplementedError('overridden in main'),
);

/// Signed-in uid (anonymous auth), null while signing in.
final authUidProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((u) => u?.uid);
});

/// Live profile document of the signed-in user.
final userProfileProvider = StreamProvider<Profile?>((ref) {
  final uid = ref.watch(authUidProvider).valueOrNull;
  if (uid == null) return Stream.value(null);
  return mysosDb
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? Profile.fromDoc(doc.id, doc.data()) : null);
});

final alertServiceProvider = Provider<AlertService>((_) => AlertService());
final pairingServiceProvider = Provider<PairingService>((_) => PairingService());

/// Profiles of the caregivers linked to the signed-in user.
final caregiversProvider = StreamProvider<List<Profile>>((ref) {
  final uid = ref.watch(authUidProvider).valueOrNull;
  if (uid == null) return Stream.value(const []);
  return mysosDb
      .collection('users')
      .where('caregiverUids', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Profile.fromDoc(d.id, d.data())).toList());
});

/// Profiles of the users this caregiver cares for.
final caredUsersProvider = StreamProvider<List<Profile>>((ref) {
  final uid = ref.watch(authUidProvider).valueOrNull;
  if (uid == null) return Stream.value(const []);
  return mysosDb
      .collection('users')
      .where('caringUids', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Profile.fromDoc(d.id, d.data())).toList());
});

/// Alert history for the signed-in user (role: user).
final userAlertsProvider = StreamProvider<List<AlertRecord>>((ref) {
  final uid = ref.watch(authUidProvider).valueOrNull;
  if (uid == null) return Stream.value(const []);
  return ref.watch(alertServiceProvider).watchUserAlerts(uid);
});

/// Alert feed for the signed-in caregiver.
final caregiverAlertsProvider = StreamProvider<List<AlertRecord>>((ref) {
  final uid = ref.watch(authUidProvider).valueOrNull;
  if (uid == null) return Stream.value(const []);
  return ref.watch(alertServiceProvider).watchCaregiverAlerts(uid);
});

/// Role chosen on the welcome screen, consumed by profile setup.
final pendingRoleProvider = StateProvider<Role?>((_) => null);

/// A mysos:// deep link (widget SOS, QR pair) that arrived while auth/profile
/// was still loading; the router consumes it once the user is resolved.
final pendingDeepLinkProvider = StateProvider<String?>((_) => null);
