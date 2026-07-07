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
  final _apiKey = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  bool _sending = false;

  Future<void> _finish() async {
    final cfg = AgentConfig(
      witnessEmail: _witness.text.trim(),
      nextDnsDohUrl: _doh.text.trim(),
      nextDnsApiKey: _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
      smtp: SmtpConfig(_host.text.trim(), int.tryParse(_port.text) ?? 587,
          _user.text.trim(), _pass.text.trim(), _user.text.trim()),
    );
    if (!cfg.isValid || _pin.text.length < 6) {
      setState(() => _error = cfg.validationErrors.join(', ') + (_pin.text.length < 6 ? ' pin>=6' : ''));
      return;
    }
    setState(() { _error = null; _sending = true; });
    try {
      final store = ConfigStore();
      await store.saveConfig(cfg);
      await store.savePinHash(Pin.hash(_pin.text));   // PBKDF2 + random salt (audit #13)
      final ch = EnforcementChannel();
      await ch.configure(cfg);
      // Self-test: prove the witness will actually be emailed BEFORE activating. If the SMTP is
      // wrong, every alert would fail silently — so we refuse to finish setup until a test lands.
      final emailErr = await ch.testEmail();
      if (emailErr != null) {
        setState(() {
          _sending = false;
          _error = 'Test email failed — protection NOT activated. Check the witness email, SMTP user, '
              'and app password, then try again.\n($emailErr)';
        });
        return;
      }
      await ch.requestAdmin();
      await ch.startVpn();
      await ch.startWatchdog();
      if (mounted) Navigator.of(context).pushReplacementNamed('/status');
    } catch (e) {
      setState(() { _sending = false; _error = 'Setup error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Witness setup')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      // autocorrect/autocapitalization OFF on every credential + address field — a phone keyboard
      // silently capitalizing or "correcting" a username/password/host is the classic cause of
      // "I typed it right but it fails".
      TextField(controller: _witness, keyboardType: TextInputType.emailAddress,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'Witness email')),
      TextField(controller: _doh, keyboardType: TextInputType.url,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'NextDNS DoH URL')),
      TextField(controller: _host, keyboardType: TextInputType.url,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'SMTP host')),
      TextField(controller: _port, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'SMTP port')),
      TextField(controller: _user, keyboardType: TextInputType.emailAddress,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'SMTP user/from')),
      TextField(controller: _pass, obscureText: true,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'SMTP app password (paste it to be safe)')),
      TextField(controller: _apiKey,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
              labelText: 'NextDNS API key (optional — enables porn-attempt emails from the phone)')),
      const Divider(),
      OutlinedButton(
        onPressed: () => EnforcementChannel().requestBatteryExemption(),
        child: const Text('1. Allow to run in background (battery) — IMPORTANT'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 8),
        child: Text('Tap and choose "Allow". Without this, reports and alerts stop when the phone idles.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
      OutlinedButton(
        onPressed: () => EnforcementChannel().requestUsageAccess(),
        child: const Text('2. Grant app-usage access (for the hourly app report)'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 8),
        child: Text('Flip the toggle for this app on the screen that opens, then come back.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
      TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Witness PIN — 6+ digits (you set, keep secret)')),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 4),
      ElevatedButton(
        onPressed: _sending ? null : _finish,
        child: Text(_sending ? 'Sending test email…' : 'Send test email & activate'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('A test email is sent to the witness first. Protection activates only if it arrives.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
    ]),
  );
}
