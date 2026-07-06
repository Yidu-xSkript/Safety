import 'package:flutter/material.dart';
import '../security/pin.dart';
import '../storage/config_store.dart';
import '../platform/enforcement_channel.dart';

class ReleaseScreen extends StatefulWidget {
  const ReleaseScreen({super.key});
  @override State<ReleaseScreen> createState() => _ReleaseScreenState();
}

class _ReleaseScreenState extends State<ReleaseScreen> {
  final _pin = TextEditingController();
  int _wrong = 0;
  String _msg = '';

  Future<void> _tryRelease() async {
    final stored = await ConfigStore().loadPinHash();
    if (stored != null && Pin.verify(_pin.text, stored)) {
      await EnforcementChannel().release();
      setState(() => _msg = 'Released. You may now uninstall the app.');
    } else {
      _wrong++;
      // Notify the witness after repeated wrong PINs — someone is trying to release without it (#7).
      if (_wrong >= 3) {
        try { await EnforcementChannel().alertReleaseAttempt(); } catch (_) {}
      }
      setState(() => _msg = 'Wrong PIN ($_wrong).');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Allow uninstall')),
        body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          const Text('Enter the witness PIN to release protection for uninstall.'),
          TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number),
          ElevatedButton(onPressed: _tryRelease, child: const Text('Release')),
          Text(_msg),
        ])),
      );
}
