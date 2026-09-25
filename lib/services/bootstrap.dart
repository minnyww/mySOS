import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'db.dart';

/// Result of booting Firebase.
class BootstrapResult {
  const BootstrapResult({required this.ok, this.error});
  final bool ok;
  final String? error;
}

/// Initialize Firebase once for the whole app.
///
/// When the app is launched with USE_FIREBASE_EMULATORS=true (env var), all
/// Auth/Firestore traffic goes to the local emulator suite instead — useful
/// for development without touching production data.
Future<BootstrapResult> bootstrapFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Usually: missing google-services.json (Android) / GoogleService-Info.plist (iOS).
    return BootstrapResult(ok: false, error: e.toString());
  }

  if (_useEmulators) {
    try {
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      mysosDb.useFirestoreEmulator('127.0.0.1', 8080);
      mysosDb.settings = const Settings(persistenceEnabled: false);
      debugPrint('[mysos] Using local Firebase emulators');
    } catch (e) {
      debugPrint('[mysos] Emulator setup failed: $e');
    }
  }
  return const BootstrapResult(ok: true);
}

bool get _useEmulators {
  if (kDebugMode) {
    final env = Platform.environment;
    if (env['USE_FIRESTORE_EMULATORS'] == 'true') return true;
    if (const bool.fromEnvironment('USE_FIRESTORE_EMULATORS')) return true;
  }
  return false;
}
