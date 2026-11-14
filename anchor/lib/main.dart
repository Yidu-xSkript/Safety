import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/shell.dart';
import 'app/theme.dart';
import 'features/onboarding/onboarding.dart';
import 'features/today/solo_controller.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(soloProvider.notifier).refreshDay());
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

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solo = ref.watch(soloProvider);
    return solo.when(
      loading: () => const Scaffold(body: SizedBox.expand()), // blank for a frame; storage reads are instant
      error: (_, _) => Scaffold(body: Center(child: Text(AppLocalizations.of(context).genericError))),
      data: (s) => s.data.onboarded ? const AnchorShell() : const WelcomeScreen(),
    );
  }
}
