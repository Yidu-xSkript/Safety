import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive_page.dart';
import '../../l10n/app_localizations.dart';

/// Phase 0 placeholder. Phase 4 builds partner, reminders, app lock, leave and delete.
class PodPage extends StatelessWidget {
  const PodPage({super.key, required this.onUrge});

  final VoidCallback onUrge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdaptivePage(
      title: l.tabPod,
      onUrge: onUrge,
      children: [Text(l.podPlaceholder, style: Theme.of(context).textTheme.bodyLarge)],
    );
  }
}
