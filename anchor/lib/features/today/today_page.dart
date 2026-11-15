import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/adaptive_page.dart';
import '../../l10n/app_localizations.dart';
import '../rings/pod_header.dart';
import 'solo_controller.dart';
import 'widgets/habits_card.dart';
import '../pod/pod_controller.dart';
import 'widgets/partner_signals.dart';
import 'widgets/pledge_card.dart';
import 'widgets/sync_row.dart';
import 'widgets/week_strip.dart';

/// You and your partner, both real (partner data comes from the pod and is cached for offline).
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key, required this.onUrge});

  final VoidCallback onUrge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(todayViewProvider);
    if (v == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final ended = ref.watch(podProvider.select((s) => s.value?.ended ?? false));

    return AdaptivePage(
      title: l.podTitle(v.name, v.partnerName),
      onUrge: onUrge,
      large: false,
      children: [
        const SyncRow(),
        const PartnerSignals(),
        PodHeader(youName: v.name, partnerName: v.partnerName, you: v.you, partner: v.partner, podStreak: v.podStreak),
        const SizedBox(height: 24),
        if (!ended) ...[
          const PledgeCard(),
          const SizedBox(height: 12),
          const HabitsCard(),
          const SizedBox(height: 12),
        ],
        WeekStrip(view: v, partnerName: v.partnerName),
      ],
    );
  }
}
