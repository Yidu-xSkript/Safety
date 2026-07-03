import 'package:flutter/material.dart';
import 'ui/setup_wizard.dart';
import 'ui/status_screen.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Accountability',
        routes: {
          '/': (_) => const SetupWizard(),
          '/status': (_) => const StatusScreen(),
        },
      );
}
