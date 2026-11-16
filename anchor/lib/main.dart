import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FlutterAuthClientOptions, Supabase;

import 'app/navigation.dart';
import 'app/shell.dart';
import 'app/theme.dart';
import 'core/backend/pod_backend.dart';
import 'core/backend/secure_session_storage.dart';
import 'core/backend/supabase_backend.dart';
import 'core/push/push_service.dart';
import 'core/shortcuts.dart';
import 'features/lock/lock_controller.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding.dart';
import 'features/pod/pairing_screens.dart';
import 'features/pod/pod_controller.dart';
import 'features/pod/push_controller.dart';
import 'features/pod/settings_controller.dart';
import 'features/today/solo_controller.dart';
import 'features/urge/urge_flow.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Pairing needs a server: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  if (supabaseConfigured) {
    await Supabase.initialize(
      url: kSupabaseUrl,
      publishableKey: kSupabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(localStorage: SecureSessionStorage()), // the session in the Keychain/Keystore
    );
  }
  // Notifications need a Firebase project (docs/PUSH.md). Without its config files this throws and we run without push.
  PushService push = NoPush();
  try {
    await Firebase.initializeApp();
    push = FirebasePush();
  } catch (_) {}
  runApp(ProviderScope(overrides: [pushServiceProvider.overrideWithValue(push)], child: const AnchorApp()));
}

class AnchorApp extends ConsumerStatefulWidget {
  const AnchorApp({super.key});

  @override
  ConsumerState<AnchorApp> createState() => _AnchorAppState();
}

class _AnchorAppState extends ConsumerState<AnchorApp> {
  // The day may roll over (04:00) while the app sleeps; re-derive "today" when it wakes.
  // ponytail: not re-checked while the app stays in the foreground across 04:00.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () => setState(() => _covered = true), // the app switcher snapshots the screen at this moment
      onHide: () => ref.read(lockProvider.notifier).leaving(),
      onPause: () => ref.read(lockProvider.notifier).leaving(),
      onResume: () {
      setState(() => _covered = false);
      ref.read(lockProvider.notifier).returned();
      ref.read(soloProvider.notifier).refreshDay();
      ref.read(podProvider.notifier).refresh(); // partner may have changed things while we slept
      ref.read(podProvider.notifier).flush();
      ref.read(pushProvider.notifier).sync(); // make sure the server has this phone's token
      ref.invalidate(reminderSyncProvider); // re-anchor the daily reminder (also after a daylight-saving change)
      },
    );
    _outside();
  }

  StreamSubscription<PushRoute>? _opened;
  bool _covered = false;

  /// Things that start outside the widget tree: the "Urge" icon shortcut and a tapped notification.
  void _outside() {
    ref.read(shortcutsProvider).init(() {
      final c = navigatorKey.currentContext;
      if (c != null) openUrge(c);
    });
    final push = ref.read(pushServiceProvider);
    _opened = push.onOpened.listen(_route);
    push.initialRoute().then((r) {
      if (r != null) _route(r);
    });
  }

  /// A notification was tapped. Refresh first (the app may have been asleep), then land where it points.
  Future<void> _route(PushRoute r) async {
    await ref.read(podProvider.future);
    await ref.read(podProvider.notifier).refresh();
    final c = navigatorKey.currentContext;
    final p = ref.read(podProvider).value;
    if (c == null || !c.mounted || r.kind != PushRouteKind.urge) return; // today / pod: the app already opens on Today
    final urge = p?.partnerUrge;
    if (urge != null) await replyToUrge(c, partnerName: p?.pod?.partnerName ?? '', urgeId: urge.id);
  }

  @override
  void dispose() {
    _opened?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(privacySyncProvider); // Android FLAG_SECURE follows the setting
    final hide = ref.watch(settingsProvider.select((s) => s.value?.hideInSwitcher ?? true));
    ref.watch(reminderSyncProvider); // schedules the daily reminder whenever the setting or today's check-in changes
    return MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => Stack(fit: StackFit.expand, children: [child!, if (_covered && hide) const PrivacyCover()]),
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      theme: anchorTheme(Brightness.light),
      darkTheme: anchorTheme(Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _Root(),
    );
  }
}

/// One screen decides where you are: onboarding, choosing a pod, waiting for your partner, or the app.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solo = ref.watch(soloProvider);
    final pod = ref.watch(podProvider);
    const blank = Scaffold(body: SizedBox.expand()); // for a frame; storage reads are instant
    if (solo.hasError || pod.hasError) {
      return Scaffold(body: Center(child: Text(AppLocalizations.of(context).genericError)));
    }
    final lock = ref.watch(lockProvider);
    if (!solo.hasValue || !pod.hasValue || !lock.hasValue) return blank;

    if (!solo.requireValue.data.onboarded) return const WelcomeScreen();
    if (lock.requireValue) return const LockScreen();
    final p = pod.requireValue;
    return switch (p.pod?.status) {
      PodStatus.active when p.justPaired => const PairedMoment(),
      PodStatus.active || PodStatus.archived => const AnchorShell(), // an ended pod stays readable (Today explains and offers a fresh start)
      PodStatus.open => const WaitingScreen(),
      null => const PodChoiceScreen(),
    };
  }
}
