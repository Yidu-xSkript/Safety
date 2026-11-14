import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive_page.dart';
import '../../l10n/app_localizations.dart';

/// Phase 0 placeholder. Phase 4 builds the month heatmap.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.onUrge});

  final VoidCallback onUrge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AdaptivePage(
      title: l.tabHistory,
      onUrge: onUrge,
      children: [Text(l.historyPlaceholder, style: Theme.of(context).textTheme.bodyLarge)],
    );
  }
}
