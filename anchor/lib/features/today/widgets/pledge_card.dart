import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive/adaptive_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../pod/pod_controller.dart';
import '../../rings/ring_model.dart';
import '../domain/models.dart';
import '../solo_controller.dart';
import 'slip_sheet.dart';

/// The daily pledge. Two honest answers, equal weight in effort (one tap each); no streak pressure on it.
class PledgeCard extends ConsumerStatefulWidget {
  const PledgeCard({super.key});

  @override
  ConsumerState<PledgeCard> createState() => _PledgeCardState();
}

class _PledgeCardState extends ConsumerState<PledgeCard> {
  bool _changing = false;

  Future<void> _held() async {
    setState(() => _changing = false);
    await ref.read(soloProvider.notifier).setPledge(PledgeState.held);
  }

  Future<void> _slipped(CheckIn? existing) async {
    final partner = ref.read(podProvider).value?.pod?.partnerName ?? '';
    final note = await showSlipSheet(context, partnerName: partner, initialNote: existing?.state == PledgeState.slipped ? existing?.note : null);
    if (note == null || !mounted) return; // "Not yet": nothing is saved
    setState(() => _changing = false);
    await ref.read(soloProvider.notifier).setPledge(PledgeState.slipped, note: note);
  }

  String _time(BuildContext context, DateTime at) {
    final loc = MaterialLocalizations.of(context);
    return loc.formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final pledge = ref.watch(soloProvider.select((s) => s.value?.pledge));
    final answered = pledge != null && !_changing;
    final pod = ref.watch(podProvider).value;
    final partner = pod?.pod?.partnerName ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: answered
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pledge.state == PledgeState.held ? l.heldAt(_time(context, pledge.at)) : l.slippedAt(_time(context, pledge.at)),
                      style: t.titleLarge,
                    ),
                    if (pledge.state == PledgeState.held && partner.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(l.heldSeen(partner), style: t.bodyLarge),
                    ],
                    if (pledge.state == PledgeState.slipped) ...[
                      const SizedBox(height: 4),
                      Text(l.slipSaved, style: t.bodyLarge),
                      if (pledge.note != null) ...[
                        const SizedBox(height: 8),
                        Text(pledge.note!, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ],
                    if ((pod?.pending ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      Text(l.queuedNote, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 4),
                    AdaptiveButton(label: l.changeAnswer, kind: ButtonKind.text, onPressed: () => setState(() => _changing = true)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.pledgePrompt, style: t.titleLarge),
                    const SizedBox(height: 12),
                    AdaptiveButton(label: l.heldTheLine, expand: true, onPressed: _held),
                    const SizedBox(height: 8),
                    AdaptiveButton(label: l.iSlipped, kind: ButtonKind.outlined, expand: true, onPressed: () => _slipped(pledge)),
                  ],
                ),
        ),
      ),
    );
  }
}
