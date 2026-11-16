import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/adaptive_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../urge/urge_flow.dart';
import 'lock_controller.dart';

/// Shown instead of the app while it is locked. It says nothing about what the app is for, and it never gets in
/// the way of reaching out: Urge opens the grounding screen even while locked.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock()); // ask straight away; the button asks again
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    await ref.read(lockProvider.notifier).unlock(AppLocalizations.of(context).lockReason);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return AdaptiveScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l.lockTitle, style: t.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                AdaptiveButton(label: l.unlock, expand: true, onPressed: _unlock),
                const SizedBox(height: 8),
                AdaptiveButton(label: l.urge, kind: ButtonKind.text, onPressed: () => openUrge(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the app switcher sees: nothing but the ground colour.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: const SizedBox.expand());
}
