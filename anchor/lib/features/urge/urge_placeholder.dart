import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Phase 0 stand-in for the Urge flow (Phase 3). Already in the night register: dim ground, one warm hue, no pure white.
class UrgePlaceholder extends StatelessWidget {
  const UrgePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NightPalette.ground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.urgePlaceholderTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: NightPalette.lampText),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: NightPalette.ember, minimumSize: const Size(48, 48)),
                  child: Text(l.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
