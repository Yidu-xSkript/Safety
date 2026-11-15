import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive/adaptive_widgets.dart';
import '../../../core/local_day.dart';
import '../../../l10n/app_localizations.dart';
import '../../pod/domain/care.dart';
import '../../pod/pod_controller.dart';
import '../../rings/ring_model.dart';
import '../../rings/slab.dart';
import '../../rings/slab_painter.dart';
import '../../urge/replies.dart';
import '../solo_controller.dart';

/// "In sync" or "Waiting on Teo", in neutral words, and (only in the evening, only when they have not
/// checked in, once a day) a way to say hello. Never a count of missed days, never "behind".
class SyncRow extends ConsumerStatefulWidget {
  const SyncRow({super.key});

  @override
  ConsumerState<SyncRow> createState() => _SyncRowState();
}

class _SyncRowState extends ConsumerState<SyncRow> {
  bool _sent = false; // hide at once, before the server answers

  @override
  Widget build(BuildContext context) {
    final solo = ref.watch(soloProvider).value;
    final p = ref.watch(podProvider).value;
    if (solo == null || p == null || !p.active) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final today = solo.today;
    final yesterday = addDays(today, -1);
    final partner = p.partner;
    final name = p.pod?.partnerName ?? '';
    final state = syncState(
      meToday: solo.data.pledgeOn(today),
      meYesterday: solo.data.pledgeOn(yesterday),
      partnerToday: partner?.pledgeOn(today),
      partnerYesterday: partner?.pledgeOn(yesterday),
    );
    if (state == SyncState.none) return const SizedBox.shrink();

    final sentToday =
        _sent ||
        p.replies.any(
          (r) =>
              r.fromMe &&
              r.template == ReplyTemplate.hello.key &&
              localDate(r.createdAt) == today,
        );
    final hello =
        state == SyncState.waitingOnPartner &&
        nudgeAvailable(
          partnerToday: partner?.pledgeOn(today),
          sentToday: sentToday,
          now: ref.read(clockProvider)(),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Flexible: a long name or large text wraps the chip instead of pushing "Say hello" off the screen.
          Flexible(
            child: Semantics(
              container: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: RingGlyph(
                          state: state == SyncState.inSync
                              ? PledgeState.held
                              : PledgeState.unchecked,
                          person: state == SyncState.inSync
                              ? Person.you
                              : Person.partner,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          state == SyncState.inSync
                              ? l.inSync
                              : l.waitingOn(name),
                          style: t.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (hello)
            AdaptiveButton(
              label: l.sayHello,
              kind: ButtonKind.text,
              onPressed: () {
                ref.read(podProvider.notifier).sayHello();
                setState(() => _sent = true);
              },
            ),
        ],
      ),
    );
  }
}
