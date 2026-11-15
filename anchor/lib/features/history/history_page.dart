import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/adaptive_page.dart';
import '../../core/adaptive/adaptive_widgets.dart';
import '../../core/local_day.dart';
import '../../l10n/app_localizations.dart';
import '../pod/pod_controller.dart';
import '../rings/ring_model.dart';
import '../rings/slab.dart';
import '../rings/slab_painter.dart';
import '../today/domain/models.dart';
import '../today/solo_controller.dart';
import 'domain/history.dart';

/// A pledge on [day] for one person: null when it is not their day yet (before they started, or the future).
PledgeState? stateOn(SoloData d, DateTime day, DateTime today) =>
    day.isAfter(today) || d.startDay == null || day.isBefore(d.startDay!) ? null : (d.pledgeOn(day) ?? PledgeState.unchecked);

/// The month at a glance: two ring glyphs a day (you on the left, your partner on the right), then the two
/// numbers that matter. Tap a day for what happened. Rings are never judged: silence is hollow, not red.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key, required this.onUrge});

  final VoidCallback onUrge;

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  DateTime? _month; // null = the current month

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final solo = ref.watch(soloProvider).value;
    final pod = ref.watch(podProvider).value;
    if (solo == null) return const SizedBox.shrink();

    final me = solo.data;
    final partner = pod?.partner;
    final today = solo.today;
    final partnerName = pod?.pod?.partnerName ?? '';
    final month = _month ?? monthStart(today);
    final starts = [me.startDay, partner?.startDay].whereType<DateTime>().toList()..sort();

    if (starts.isEmpty) {
      return AdaptivePage(
        title: l.tabHistory,
        onUrge: widget.onUrge,
        children: [Text(l.historyPlaceholder, style: Theme.of(context).textTheme.bodyLarge)],
      );
    }

    final first = monthStart(starts.first);
    final loc = MaterialLocalizations.of(context);
    final firstIdx = loc.firstDayOfWeekIndex; // 0 = Sunday
    final cells = monthCells(month, firstWeekday: firstIdx == 0 ? DateTime.sunday : firstIdx);

    return AdaptivePage(
      title: l.tabHistory,
      onUrge: widget.onUrge,
      children: [
        _MonthBar(
          title: loc.formatMonthYear(month),
          onPrev: month.isAfter(first) ? () => setState(() => _month = dayOf(month.year, month.month - 1, 1)) : null,
          onNext: month.isBefore(monthStart(today)) ? () => setState(() => _month = dayOf(month.year, month.month + 1, 1)) : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    loc.narrowWeekdays[(firstIdx + i) % 7],
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < cells.length ~/ 7; w++)
          Row(
            children: [
              for (final day in cells.sublist(w * 7, w * 7 + 7))
                Expanded(
                  child: day == null
                      ? const SizedBox(height: 64)
                      : _DayCell(
                          day: day,
                          isToday: day == today,
                          you: stateOn(me, day, today),
                          partner: partner == null ? null : stateOn(partner, day, today),
                          youName: me.name,
                          partnerName: partnerName,
                          onTap: () => showDaySheet(context, day: day, me: me, partner: partner, partnerName: partnerName, today: today),
                        ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        _Legend(youName: me.name, partnerName: partnerName, paired: partner != null),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Stats(name: me.name, data: me, month: month, today: today)),
                if (partner != null) ...[
                  const SizedBox(width: 16),
                  Expanded(child: _Stats(name: partnerName, data: partner, month: month, today: today)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.title, this.onPrev, this.onNext});

  final String title;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ios = isIOS(context);
    Widget arrow(IconData icon, String tip, VoidCallback? on) => Semantics(
          button: true,
          label: tip,
          child: ios
              ? CupertinoButton(padding: EdgeInsets.zero, minimumSize: const Size(44, 44), onPressed: on, child: Icon(icon))
              : IconButton(onPressed: on, icon: Icon(icon), tooltip: tip),
        );
    return Row(
      children: [
        arrow(ios ? CupertinoIcons.chevron_left : Icons.chevron_left, l.prevMonth, onPrev),
        Expanded(child: Center(child: Text(title, style: Theme.of(context).textTheme.titleLarge))),
        arrow(ios ? CupertinoIcons.chevron_right : Icons.chevron_right, l.nextMonth, onNext),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.you,
    required this.partner,
    required this.youName,
    required this.partnerName,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final PledgeState? you;
  final PledgeState? partner;
  final String youName;
  final String partnerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final label = l.weekDayLabel(
      MaterialLocalizations.of(context).formatMediumDate(day),
      [
        if (you != null) l.weekPersonState(youName, ringWordText(l, you!)),
        if (partner != null) l.weekPersonState(partnerName, ringWordText(l, partner!)),
      ].join(', '),
    );
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 64, // a comfortable tap target even though the glyphs are small
            child: LayoutBuilder(builder: (context, c) {
              final g = ((c.maxWidth - 6) / 2).clamp(10.0, 20.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: t.labelMedium?.copyWith(
                      color: isToday ? context.paletteYou : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: g, height: g, child: you == null ? null : RingGlyph(state: you!, person: Person.you, size: g)),
                      SizedBox(width: g, height: g, child: partner == null ? null : RingGlyph(state: partner!, person: Person.partner, size: g)),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

extension on BuildContext {
  Color get paletteYou => Theme.of(this).colorScheme.primary;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.youName, required this.partnerName, required this.paired});

  final String youName;
  final String partnerName;
  final bool paired;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    Widget item(PledgeState s, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [RingGlyph(state: s, person: Person.you, size: 16), const SizedBox(width: 6), Flexible(child: Text(text, style: t.bodyMedium))],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [item(PledgeState.held, l.legendHeld), item(PledgeState.slipped, l.legendSlipped), item(PledgeState.unchecked, l.legendNone)],
        ),
        if (paired) ...[
          const SizedBox(height: 8),
          Text(l.legendSides(youName, partnerName), style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.name, required this.data, required this.month, required this.today});

  final String name;
  final SoloData data;
  final DateTime month;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final since = data.startDay ?? today;
    final best = bestStreak(data.pledgeOn, since: since, until: today);
    final held = daysHeldIn(data.pledgeOn, month, since: since, until: today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Text(l.bestStreakLabel, style: t.labelMedium?.copyWith(color: muted)),
        Text(l.countDays(best), style: t.titleMedium),
        const SizedBox(height: 8),
        Text(l.heldThisMonthLabel, style: t.labelMedium?.copyWith(color: muted)),
        Text(l.countDays(held), style: t.titleMedium),
      ],
    );
  }
}

/// What happened on [day], for each of you: the pledge in words, any note, and the habits done.
Future<void> showDaySheet(
  BuildContext context, {
  required DateTime day,
  required SoloData me,
  required SoloData? partner,
  required String partnerName,
  required DateTime today,
}) {
  return adaptiveSheet<void>(context, (ctx) {
    final l = AppLocalizations.of(ctx);
    final t = Theme.of(ctx).textTheme;
    final loc = MaterialLocalizations.of(ctx);
    Widget person(SoloData d, String name, Person who) {
      final s = stateOn(d, day, today);
      if (s == null) return const SizedBox.shrink();
      final note = d.checkIns[dayKey(day)]?.note;
      final counts = d.countsOn(day);
      final ticked = [for (final h in d.habits) if (h.activeOn(day) && (d.logs[dayKey(day)] ?? const {}).contains(h.id)) h.title];
      final word = switch (s) {
        PledgeState.held => l.heldTheLine,
        PledgeState.slipped => l.legendSlipped,
        PledgeState.unchecked => l.legendNone,
      };
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2, right: 12), child: RingGlyph(state: s, person: who, size: 24)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.dayPerson(name, word), style: t.titleMedium),
                  if (note != null && note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note, style: t.bodyLarge)),
                  if (counts.total > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        ticked.isEmpty ? l.dayHabits(counts.done, counts.total) : '${l.dayHabits(counts.done, counts.total)} · ${ticked.join(', ')}',
                        style: t.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.formatFullDate(day), style: t.headlineMedium),
          const SizedBox(height: 16),
          person(me, me.name, Person.you),
          if (partner != null) person(partner, partnerName, Person.partner),
        ],
      ),
    );
  });
}
