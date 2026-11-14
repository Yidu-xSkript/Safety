import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'app/shell.dart';
import 'app/theme.dart';
import 'core/backend/pod_backend.dart';
import 'core/backend/supabase_backend.dart';
import 'features/onboarding/onboarding.dart';
import 'features/pod/pairing_screens.dart';
import 'features/pod/pod_controller.dart';
import 'features/today/solo_controller.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Pairing needs a server: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  if (supabaseConfigured) await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseAnonKey);
  runApp(const ProviderScope(child: AnchorApp()));
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
    _lifecycle = AppLifecycleListener(onResume: () {
      ref.read(soloProvider.notifier).refreshDay();
      ref.read(podProvider.notifier).refresh(); // partner may have changed things while we slept
      ref.read(podProvider.notifier).flush();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    if (!solo.hasValue || !pod.hasValue) return blank;

    if (!solo.requireValue.data.onboarded) return const WelcomeScreen();
    final p = pod.requireValue;
    return switch (p.pod?.status) {
      PodStatus.active when p.justPaired => const PairedMoment(),
      PodStatus.active => const AnchorShell(),
      PodStatus.open => const WaitingScreen(),
      // ponytail: an archived pod (partner left) sends you back to choose; the "your pod has ended" view comes with leave-pod in Phase 4.
      PodStatus.archived || null => const PodChoiceScreen(),
    };
  }
}
