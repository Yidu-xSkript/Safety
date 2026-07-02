import 'package:flutter/material.dart';
import 'release_screen.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Protection active')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.shield, size: 96, color: Colors.green),
            const Text('Accountability protection is active.'),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReleaseScreen())),
              child: const Text('Allow uninstall (witness PIN)'),
            ),
          ]),
        ),
      );
}
