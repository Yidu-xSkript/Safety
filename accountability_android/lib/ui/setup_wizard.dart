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
  final _token = TextEditingController();
  final _chat = TextEditingController();
  final _doh = TextEditingController();
  final _apiKey = TextEditingController();
  final _pin = TextEditingController();
  String? _error;
  bool _sending = false;

  Future<void> _finish() async {
    final cfg = AgentConfig(
      telegramBotToken: _token.text.trim(),
      telegramChatId: _chat.text.trim(),
      nextDnsDohUrl: _doh.text.trim(),
      nextDnsApiKey: _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
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
      // Self-test: prove the channel will actually be told BEFORE activating. If the bot token or
      // channel is wrong, every alert would fail silently — so we refuse to finish setup until a test lands.
      final sendErr = await ch.testReport();
      if (sendErr != null) {
        setState(() {
          _sending = false;
          _error = 'Test message failed — protection NOT activated. Check the bot token and channel, and '
              'that the bot is an admin of the channel, then try again.\n($sendErr)';
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
      TextField(controller: _token,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'Telegram bot token (from @BotFather — paste it)')),
      TextField(controller: _chat,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
              labelText: 'Telegram channel (@channelname, or -100… for a private one)')),
      TextField(controller: _doh, keyboardType: TextInputType.url,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(labelText: 'NextDNS DoH URL')),
      TextField(controller: _apiKey,
          autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
              labelText: 'NextDNS API key (optional — enables porn-attempt alerts from the phone)')),
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
        child: const Text('2. Grant app-usage access (for the app report)'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 8),
        child: Text('Flip the toggle for this app on the screen that opens, then come back.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
      OutlinedButton(
        onPressed: () => EnforcementChannel().openAppInfo(),
        child: const Text('3. Telegram watch: allow restricted settings (Android 13+)'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 8),
        child: Text('On the App info screen: menu (⋮) > "Allow restricted settings". Skip if there is no such menu.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
      OutlinedButton(
        onPressed: () => EnforcementChannel().requestTelegramWatch(),
        child: const Text('4. Turn on the Telegram watch (reports chat/channel names)'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 8),
        child: Text('Accessibility > installed apps > this app > switch on. It reads chat titles in Telegram only, never messages.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
      TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Witness PIN — 6+ digits (you set, keep secret)')),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 4),
      ElevatedButton(
        onPressed: _sending ? null : _finish,
        child: Text(_sending ? 'Sending test message…' : 'Send test message & activate'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('A test message is posted to the Telegram channel first. Protection activates only if it arrives.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ),
    ]),
  );
}
