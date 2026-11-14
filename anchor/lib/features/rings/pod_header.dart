import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'ring_model.dart';
import 'slab.dart';
import 'slab_painter.dart';

/// Two equal slabs joined by a thin line, their day counts beneath, the pod streak below.
/// Neither person is the hero: identical size, identical weight.
class PodHeader extends StatelessWidget {
  const PodHeader({
    super.key,
    required this.youName,
    required this.partnerName,
    required this.you,
    required this.partner,
    required this.podStreak,
  });

  final String youName;
  final String partnerName;
  final SlabData you;
  final SlabData partner;
  final int podStreak;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(builder: (context, c) {
      // Shrinks toward 120dp as text grows toward 200%, and never wider than the space allows.
      final byText = kSlabBase - (kSlabBase - 120) * (textScale - 1).clamp(0.0, 1.0);
      final byWidth = (c.maxWidth - 32) / 2;
      final d = math.min(byText, byWidth);

      Widget count(String name, int days, Person who) => SizedBox(
            width: math.max(d, 96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                FittedBox(fit: BoxFit.scaleDown, child: Text('$days', style: theme.textTheme.displayLarge)),
                Text(l.daysHeld, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Slab(name: youName, data: you, person: Person.you, diameter: d),
              Expanded(
                child: Center(child: Container(height: 1.5, color: context.palette.hollow.withValues(alpha: 0.5))),
              ),
              Slab(name: partnerName, data: partner, person: Person.partner, diameter: d),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [count(youName, you.daysHeld, Person.you), count(partnerName, partner.daysHeld, Person.partner)],
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(999)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(l.podStreak(podStreak), style: theme.textTheme.labelLarge),
            ),
          ),
        ],
      );
    });
  }
}
