import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/adaptive/adaptive_widgets.dart';
import '../../../core/local_day.dart';
import '../../../l10n/app_localizations.dart';
import '../../pod/account_controller.dart';
import '../../pod/email_flow.dart';
import '../../pod/pod_controller.dart';
import '../../pod/settings_controller.dart';
import '../../pod/push_controller.dart';
import '../../rings/ring_model.dart';
import '../../urge/replies.dart';
import '../../urge/urge_flow.dart';
import '../solo_controller.dart';

/// What your partner just did that you may want to answer: reaching out, a slip, a kind word, and (once) the
/// reason to turn notifications on. Quiet when there is nothing to say.
class PartnerSignals extends ConsumerWidget {
  const PartnerSignals({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solo = ref.watch(soloProvider).value;
    final p = ref.watch(podProvider).value;
    final push = ref.watch(pushProvider).value;
    final account = ref.watch(accountProvider).value;
    final settings = ref.watch(settingsProvider).value;
    if (solo == null || p == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    // The partner left: everything stays readable, nothing can be written. The one thing to do is start again.
    if (p.ended) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _Signal(
          title: l.endedTitle,
          body: l.endedBody,
          action: l.endedStart,
          onAction: () => ref.read(podProvider.notifier).leavePod(),
        ),
      );
    }
    if (!p.active) return const SizedBox.shrink();
    final name = p.pod?.partnerName ?? '';
    final today = solo.today;
    final cards = <Widget>[];

    final urge = p.partnerUrge;
    if (urge != null) {
      final replied = p.replies.any((r) => r.fromMe && r.urgeId == urge.id);
      cards.add(_Signal(
        title: l.reachingOut(name),
        action: replied ? null : l.replyAction,
        onAction: () => replyToUrge(context, partnerName: name, urgeId: urge.id),
      ));
    } else if (p.partner?.pledgeOn(today) == PledgeState.slipped) {
      final replied = p.replies.any((r) => r.fromMe && r.urgeId == null && localDate(r.createdAt) == today);
      cards.add(_Signal(
        title: l.postedUpdate(name),
        body: p.partner?.checkIns[dayKey(today)]?.note,
        action: replied ? null : l.replyAction,
        onAction: () => replyToUpdate(context, partnerName: name),
      ));
    }

    final kind = p.replies.where((r) => !r.fromMe && r.urgeId == null && localDate(r.createdAt) == today).firstOrNull;
    final template = kind == null ? null : ReplyTemplate.fromKey(kind.template);
    if (template != null) cards.add(_Signal(title: l.urgeReplyLine(name, replyText(l, template))));

    if (push != null && push.shouldPrompt) {
      cards.add(_Signal(
        title: l.pushRationaleTitle(name),
        body: l.pushRationaleBody,
        action: l.pushEnable,
        onAction: () => ref.read(pushProvider.notifier).enable(),
        secondary: l.pushNotNow,
        onSecondary: () => ref.read(pushProvider.notifier).dismiss(),
      ));
    }

    // From day two, twice at most: a lost phone should not mean a new pod.
    final started = solo.data.startDay;
    final canSecure = ref.watch(backendProvider).configured; // securing needs a server
    if (canSecure && account != null && !account.secured && settings != null && settings.secureDismissed < 2 && !ref.watch(secureHiddenProvider) && started != null && solo.today.isAfter(started)) {
      cards.add(_Signal(
        title: l.settingsSecure,
        body: l.secureCardBody,
        action: l.secureCardAction,
        onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SecureScreen())),
        secondary: l.pushNotNow,
        onSecondary: () {
          ref.read(secureHiddenProvider.notifier).hide();
          ref.read(settingsProvider.notifier).dismissSecure();
        },
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: c)]),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({required this.title, this.body, this.action, this.onAction, this.secondary, this.onSecondary});

  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleLarge),
            if (body != null && body!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body!, style: t.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              AdaptiveButton(label: action!, expand: true, onPressed: onAction),
            ],
            if (secondary != null) AdaptiveButton(label: secondary!, kind: ButtonKind.text, onPressed: onSecondary),
          ],
        ),
      ),
    );
  }
}
