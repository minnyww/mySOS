import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config.dart';
import 'services/bootstrap.dart';
import 'state/providers.dart';

/// Handles data-only push messages while the app is in background/killed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Sign in anonymously, retrying in the background — a cold start (e.g. a
/// widget tap) must never park on the splash forever because one network
/// blip ate the sign-in. authStateChanges picks the uid up on success.
Future<void> _ensureSignedIn() async {
  for (var attempt = 1; attempt <= 5; attempt++) {
    try {
      if (FirebaseAuth.instance.currentUser != null) return;
      await FirebaseAuth.instance.signInAnonymously();
      return;
    } catch (e) {
      debugPrint('[mysos] anonymous sign-in attempt $attempt failed: $e');
      if (attempt < 5) await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}

/// The engine exposes the launch URI (widget tap / QR link on a killed app)
/// via `defaultRouteName`, but go_router cannot match a scheme URI and
/// collapses it to "/" before the redirect ever sees it — the intent is lost.
/// Normalize and return it here so main() can seed pendingDeepLink instead.
String? _seedDeepLink(String? raw) {
  if (raw == null || !raw.startsWith('${AppConfig.deepLinkScheme}://')) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.host == 'fire') return '/fire';
  final code = RegExp(r'^/?([0-9]{6})$').firstMatch(uri.path)?.group(1);
  if (uri.host == 'pair' && code != null) return '/pair/$code';
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final seedLink =
      _seedDeepLink(WidgetsBinding.instance.platformDispatcher.defaultRouteName);
  debugPrint('[mysos] boot: defaultRouteName='
      '"${WidgetsBinding.instance.platformDispatcher.defaultRouteName}" '
      'seed=$seedLink');
  final boot = await bootstrapFirebase();
  if (boot.ok) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // Non-blocking: run the first frame (and deep-link routing) without
    // waiting on the network — the router parks on /splash until a uid
    // arrives, and the retry loop above keeps a transient failure from
    // stranding the app there.
    unawaited(_ensureSignedIn());
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseBootProvider.overrideWithValue(boot),
        // A widget/QR launch of a killed app: the router replays this once
        // auth + profile resolve (see the redirect in app.dart).
        if (seedLink != null)
          pendingDeepLinkProvider.overrideWith((_) => seedLink),
      ],
      child: const MyApp(),
    ),
  );
}
