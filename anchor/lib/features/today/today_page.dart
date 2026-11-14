import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive_page.dart';
import '../rings/demo_data.dart';
import '../rings/pod_header.dart';

/// Phase 0: the pod header on synthetic data. Phase 1 adds the pledge card, habits and week strip.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.onUrge});

  final VoidCallback onUrge;

  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      title: 'Mika & Teo', // synthetic
      onUrge: onUrge,
      children: [
        PodHeader(youName: 'Mika', partnerName: 'Teo', you: demoYou, partner: demoPartner, podStreak: 14),
      ],
    );
  }
}
