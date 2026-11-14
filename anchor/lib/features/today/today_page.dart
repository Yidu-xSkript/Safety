import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/adaptive_page.dart';
import '../../l10n/app_localizations.dart';
import '../rings/demo_data.dart';
import '../rings/pod_header.dart';
import 'solo_controller.dart';
import 'widgets/habits_card.dart';
import 'widgets/pledge_card.dart';
import 'widgets/week_strip.dart';

/// Phase 1: you are real, your partner is the synthetic Teo (demo_data.dart) until pairing lands in Phase 2.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key, required this.onUrge});

  final VoidCallback onUrge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(todayViewProvider);
    if (v == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    return AdaptivePage(
      title: l.podTitle(v.name, kDemoPartnerName),
      onUrge: onUrge,
      large: false,
      children: [
        PodHeader(youName: v.name, partnerName: kDemoPartnerName, you: v.you, partner: v.partner, podStreak: v.podStreak),
        const SizedBox(height: 24),
        const PledgeCard(),
        const SizedBox(height: 12),
        const HabitsCard(),
        const SizedBox(height: 12),
        WeekStrip(view: v, partnerName: kDemoPartnerName),
      ],
    );
  }
}
