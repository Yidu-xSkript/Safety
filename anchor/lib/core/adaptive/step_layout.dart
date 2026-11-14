import 'package:flutter/material.dart';

import 'adaptive_widgets.dart';

/// A full-screen step: optional back button, scrolling content, pinned actions. Onboarding and pairing share it.
class StepLayout extends StatelessWidget {
  const StepLayout({super.key, required this.children, required this.actions});

  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Align(alignment: Alignment.centerLeft, child: Navigator.canPop(context) ? const BackButton() : const SizedBox(height: 48)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: actions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
