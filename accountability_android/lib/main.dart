import 'package:flutter/material.dart';
import 'storage/config_store.dart';
import 'platform/enforcement_channel.dart';
import 'ui/setup_wizard.dart';
import 'ui/status_screen.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Accountability',
        home: const _Bootstrap(),
        routes: {
          '/setup': (_) => const SetupWizard(),
          '/status': (_) => const StatusScreen(),
        },
      );
}

// On launch, send an already-configured device straight to status (re-applying native config + the
// watchdog in this fresh process); otherwise show the setup wizard. Without this the app always
// opened a blank setup wizard on relaunch and never repopulated native enforcement state (audit #10).
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final cfg = await ConfigStore().loadConfig();
    if (!mounted) return;
    if (cfg != null && cfg.smtp != null) {
      try {
        final ch = EnforcementChannel();
        await ch.configure(cfg);
        await ch.startWatchdog();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/status');
    } else {
      Navigator.of(context).pushReplacementNamed('/setup');
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
