import 'package:flutter/material.dart';
import '../platform/enforcement_channel.dart';
import 'release_screen.dart';

// Shows the REAL protection state instead of a hardcoded green "active" label (audit #12): if the
// friend denied the VPN/admin prompt or disabled protection, the witness must see red, not a false
// "all good". Refreshes on open and whenever the app is resumed.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});
  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> with WidgetsBindingObserver {
  Map<String, bool>? _s;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await EnforcementChannel().status();
      if (mounted) setState(() => _s = s);
    } catch (_) {
      if (mounted) setState(() => _s = {'vpn': false, 'admin': false, 'watchdog': false});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final allOn = s != null && s.values.every((v) => v);
    return Scaffold(
      appBar: AppBar(title: const Text('Protection status')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: Column(children: [
              Icon(allOn ? Icons.shield : Icons.gpp_bad, size: 96,
                  color: s == null ? Colors.grey : (allOn ? Colors.green : Colors.red)),
              Text(
                s == null ? 'Checking…' : (allOn ? 'Protection is active.' : 'PROTECTION INCOMPLETE'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: s == null ? Colors.grey : (allOn ? Colors.green : Colors.red)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _row('DNS filtering (VPN)', s?['vpn']),
          _row('Uninstall protection (device admin)', s?['admin']),
          _row('Background watchdog', s?['watchdog']),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ReleaseScreen())),
            child: const Text('Allow uninstall (witness PIN)'),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, bool? on) => ListTile(
        leading: Icon(
            on == null ? Icons.hourglass_empty : (on ? Icons.check_circle : Icons.cancel),
            color: on == null ? Colors.grey : (on ? Colors.green : Colors.red)),
        title: Text(label),
        subtitle: Text(on == null ? '…' : (on ? 'On' : 'OFF')),
      );
}
