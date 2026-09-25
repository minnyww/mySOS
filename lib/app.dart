import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config.dart';
import 'models.dart';
import 'screens/alert_detail_screen.dart';
import 'screens/caregiver_home_screen.dart';
import 'screens/confirm_pair_screen.dart';
import 'screens/enter_code_screen.dart';
import 'screens/pair_share_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/user_home_screen.dart';
import 'services/fcm_service.dart';
import 'state/providers.dart';
import 'theme.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bridges provider changes into GoRouter refreshes.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(firebaseBootProvider, (_, __) => refresh.ping());
  ref.listen(authUidProvider, (_, __) => refresh.ping());
  ref.listen(userProfileProvider, (prev, next) {
    refresh.ping();
  });
  ref.listen(notificationTapProvider, (_, __) => refresh.ping());

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refresh,
    initialLocation: '/splash',
    redirect: (context, state) {
      // Platform deep links arrive as scheme URIs (mysos://fire/,
      // mysos://pair/<code>) that no GoRoute can match — normalize them into
      // internal paths before any guard looks at the location.
      String loc = state.matchedLocation;
      if (state.uri.scheme == AppConfig.deepLinkScheme) {
        if (state.uri.host == 'fire') {
          loc = '/fire';
        } else if (state.uri.host == 'pair') {
          final code =
              RegExp(r'^/?([0-9]{6})$').firstMatch(state.uri.path)?.group(1);
          if (code != null) loc = '/pair/$code';
        }
      }

      final boot = ref.read(firebaseBootProvider);
      if (!boot.ok) return loc == '/setup' ? null : '/setup';

      final uid = ref.read(authUidProvider).valueOrNull;
      if (uid == null) {
        // Cold start from the widget/QR: keep the intent until sign-in lands.
        if (loc == '/fire' || loc.startsWith('/pair/')) {
          ref.read(pendingDeepLinkProvider.notifier).state = loc;
        }
        return loc == '/splash' ? null : '/splash';
      }

      final profileAsync = ref.read(userProfileProvider);
      final profile = profileAsync.valueOrNull;

      // A tapped SOS notification always wins.
      final tapped = ref.read(notificationTapProvider);
      if (tapped != null && tapped.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(notificationTapProvider.notifier).state = null;
        });
        return '/alerts/$tapped';
      }

      if (profile == null || profile.role == null) {
        // Same race one step later: auth resolved but the profile doc is
        // still loading. Stash the intent here too — the mysos:// URI never
        // comes back as a location, so dropping it here means a widget tap
        // silently lands on the home screen. A held /fire parks on splash
        // (an SOS must not flash the onboarding UI); a held /pair lets
        // onboarding proceed and replays once the profile exists.
        //
        // When the stream has already settled with no doc for this uid, the
        // user simply has no profile yet: let onboarding run, and drop a
        // held /fire — it must not auto-fire an SOS the moment setup
        // completes.
        final noProfile =
            !profileAsync.isLoading && profileAsync.hasValue && profile == null;
        if (!noProfile && (loc == '/fire' || loc.startsWith('/pair/'))) {
          ref.read(pendingDeepLinkProvider.notifier).state = loc;
        }
        if (noProfile && loc == '/fire') {
          ref.read(pendingDeepLinkProvider.notifier).state = null;
        }
        if (!noProfile &&
            (loc == '/fire' || ref.read(pendingDeepLinkProvider) == '/fire')) {
          return loc == '/splash' ? null : '/splash';
        }
        return (loc == '/welcome' || loc == '/profile-setup') ? null : '/welcome';
      }

      final home = profile.role == Role.user ? '/user' : '/caregiver';

      // Replay a deep link that arrived before the user was resolved.
      final pending = ref.read(pendingDeepLinkProvider);
      if (pending != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(pendingDeepLinkProvider.notifier).state = null;
        });
        if (pending == '/fire') {
          return profile.role == Role.user ? '/sos?source=widget' : home;
        }
        return pending;
      }

      if (loc == '/splash' || loc == '/welcome' || loc == '/profile-setup') {
        return home;
      }
      // Widget shortcut: caregivers land home; users go straight to the SOS flow.
      if (loc == '/fire') {
        return profile.role == Role.user ? '/sos?source=widget' : home;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const RoleSelectScreen()),
      GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: '/user', builder: (_, __) => const UserHomeScreen()),
      GoRoute(path: '/caregiver', builder: (_, __) => const CaregiverHomeScreen()),
      GoRoute(
        path: '/sos',
        builder: (_, state) => SosScreen(
          source: state.uri.queryParameters['source'] == 'widget' ? 'widget' : 'app',
        ),
      ),
      GoRoute(path: '/pair', builder: (_, __) => const PairShareScreen()),
      GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
      GoRoute(path: '/enter-code', builder: (_, __) => const EnterCodeScreen()),
      GoRoute(
        path: '/pair/:code',
        builder: (_, state) => ConfirmPairScreen(code: state.pathParameters['code'] ?? ''),
      ),
      GoRoute(
        path: '/alerts/:id',
        builder: (_, state) => AlertDetailScreen(alertId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
    errorBuilder: (context, state) {
      // Any location that still fails to match (e.g. a malformed mysos://
      // link) lands here instead of a red GoException screen.
      final role = ref.read(userProfileProvider).valueOrNull?.role;
      final home = role == Role.user ? '/user' : (role == null ? '/splash' : '/caregiver');
      return Scaffold(
        appBar: AppBar(title: const Text('ไม่พบหน้านี้')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off, size: 56, color: Colors.black38),
              const SizedBox(height: 16),
              const Text('ลิงก์ไม่ถูกต้อง หรือหน้านี้ไม่มีอีกแล้ว',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(home),
                child: const Text('กลับหน้าหลัก'),
              ),
            ],
          ),
        ),
      );
    },
  );

  // Navigate directly on notification taps instead of relying solely on the
  // redirect — if guards aren't ready yet the redirect parks on /splash, and
  // the still-set tap state carries the navigation once the user resolves.
  ref.listen<String?>(notificationTapProvider, (_, next) {
    if (next != null && next.isNotEmpty) {
      router.go('/alerts/$next');
    }
  });

  return router;
});

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool _fcmSetupDone = false;
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Register for push as soon as we know who we are. The latch resets when
    // the profile disappears (e.g. doc deleted and re-created during setup),
    // so a fresh profile always re-registers its FCM token.
    ref.listenManual(userProfileProvider, (prev, next) {
      final profile = next.valueOrNull;
      if (profile == null || profile.role == null) {
        _fcmSetupDone = false;
        return;
      }
      _lastUid = profile.uid;
      if (!_fcmSetupDone) {
        _fcmSetupDone = true;
        setupFcm(
          uid: profile.uid,
          onTapAlert: (alertId) {
            ref.read(notificationTapProvider.notifier).state = alertId;
          },
        );
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Idempotent re-registration — heals tokens lost to earlier rules
    // rejections or profile re-creation.
    if (state == AppLifecycleState.resumed && _lastUid != null) {
      registerFcmToken(_lastUid!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('th'),
      supportedLocales: const [Locale('th'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
