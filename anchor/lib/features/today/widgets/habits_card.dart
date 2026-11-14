import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../solo_controller.dart';

/// Today's habits as native checkbox rows. Ticking one sweeps today's ring (the slab animates itself).
class HabitsCard extends ConsumerWidget {
  const HabitsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(soloProvider).value;
    if (s == null || s.habits.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = s.habitsToday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.habitsHeading, style: t.titleLarge)),
                Text(l.habitsProgress(c.done, c.total), style: t.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            for (final h in s.habits)
              CheckboxListTile.adaptive(
                activeColor: Theme.of(context).colorScheme.primary, // iOS defaults to system blue
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(h.title),
                value: s.isTicked(h),
                onChanged: (_) => ref.read(soloProvider.notifier).toggleHabit(h),
              ),
          ],
        ),
      ),
    );
  }
}
