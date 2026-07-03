import 'package:flutter/material.dart';
import '../config/agent_config.dart';
import '../security/pin.dart';
import '../storage/config_store.dart';
import '../platform/enforcement_channel.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});
  @override State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  final _witness = TextEditingController();
  final _doh = TextEditingController();
  final _host = TextEditingController(text: 'smtp.gmail.com');
  final _port = TextEditingController(text: '587');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pin = TextEditingController();
  String? _error;

  Future<void> _finish() async {
    final cfg = AgentConfig(
      witnessEmail: _witness.text.trim(),
      nextDnsDohUrl: _doh.text.trim(),
      smtp: SmtpConfig(_host.text.trim(), int.tryParse(_port.text) ?? 587,
          _user.text.trim(), _pass.text, _user.text.trim()),
    );
    if (!cfg.isValid || _pin.text.length < 4) {
      setState(() => _error = cfg.validationErrors.join(', ') + (_pin.text.length < 4 ? ' pin>=4' : ''));
      return;
    }
    final store = ConfigStore();
    await store.saveConfig(cfg);
    await store.savePinHash(Pin.hash(_pin.text, salt: DateTime.now().microsecondsSinceEpoch.toString()));
    final ch = EnforcementChannel();
    await ch.configure(cfg);
    await ch.requestAdmin();
    await ch.startVpn();
    await ch.startWatchdog();
    if (mounted) Navigator.of(context).pushReplacementNamed('/status');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Witness setup')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: _witness, decoration: const InputDecoration(labelText: 'Witness email')),
      TextField(controller: _doh, decoration: const InputDecoration(labelText: 'NextDNS DoH URL')),
      TextField(controller: _host, decoration: const InputDecoration(labelText: 'SMTP host')),
      TextField(controller: _port, decoration: const InputDecoration(labelText: 'SMTP port')),
      TextField(controller: _user, decoration: const InputDecoration(labelText: 'SMTP user/from')),
      TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'SMTP app password')),
      const Divider(),
      TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Witness PIN (you set, keep secret)')),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      ElevatedButton(onPressed: _finish, child: const Text('Activate protection')),
    ]),
  );
}
