import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/bootstrap.dart';
import 'state/providers.dart';

/// Handles data-only push messages while the app is in background/killed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final boot = await bootstrapFirebase();
  if (boot.ok) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      debugPrint('[mysos] anonymous sign-in failed: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [firebaseBootProvider.overrideWithValue(boot)],
      child: const MyApp(),
    ),
  );
}
