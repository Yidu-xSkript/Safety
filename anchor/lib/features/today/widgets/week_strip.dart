import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../rings/slab.dart';
import '../../rings/slab_painter.dart';
import '../solo_controller.dart';

/// Seven days, two rows of ring glyphs: you, then your partner. Each column is one semantic node.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.view, required this.partnerName});

  final TodayView view;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget nameCell(String name) => SizedBox(
          width: 52,
          height: 40,
          child: Align(alignment: Alignment.centerLeft, child: Text(name, style: t.labelMedium?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.weekHeading, style: t.titleLarge),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [const SizedBox(height: 24), nameCell(view.name), nameCell(partnerName)]),
                for (final d in view.week)
                  Expanded(
                    child: Semantics(
                      container: true,
                      label: l.weekDayLabel(
                        loc.formatMediumDate(d.day),
                        [
                          if (d.you != null) l.weekPersonState(view.name, ringWordText(l, d.you!)),
                          l.weekPersonState(partnerName, ringWordText(l, d.partner)),
                        ].join(', '),
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            SizedBox(
                              height: 24,
                              child: Text(
                                loc.narrowWeekdays[d.day.weekday % 7],
                                style: t.labelMedium?.copyWith(
                                  color: d.day == view.today ? context.palette.you : muted,
                                  fontWeight: d.day == view.today ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(height: 40, child: Center(child: d.you == null ? null : RingGlyph(state: d.you!, person: Person.you))),
                            SizedBox(height: 40, child: Center(child: RingGlyph(state: d.partner, person: Person.partner))),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
