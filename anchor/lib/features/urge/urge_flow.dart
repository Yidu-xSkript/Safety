import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../pod/pod_controller.dart';
import '../rings/ring_model.dart';
import '../today/solo_controller.dart';
import '../today/widgets/slip_sheet.dart';
import 'replies.dart';
import 'reply_sheet.dart';
import 'urge_screen.dart';

/// True while the Urge screen is open, so a shortcut, a push tap and a button press can never stack two.
class _UrgeOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

final urgeOpenProvider = NotifierProvider<_UrgeOpen, bool>(_UrgeOpen.new);

/// Opens the grounding screen. Instant: no confirmation, no waiting on the network.
/// "I slipped" at the end continues into the same gentle slip sheet Today uses.
Future<void> openUrge(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  if (container.read(urgeOpenProvider)) return;
  container.read(urgeOpenProvider.notifier).set(true);
  final nav = Navigator.of(context);
  UrgeResult? result;
  try {
    result = await nav.push<UrgeResult>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const UrgeScreen()));
  } finally {
    container.read(urgeOpenProvider.notifier).set(false);
  }
  if (result == UrgeResult.slipped && context.mounted) {
    final partner = container.read(podProvider).value?.pod?.partnerName ?? '';
    final note = await showSlipSheet(context, partnerName: partner);
    if (note != null) await container.read(soloProvider.notifier).setPledge(PledgeState.slipped, note: note);
  }
}

/// The partner is reaching out: one tap to answer in prepared words.
Future<void> replyToUrge(BuildContext context, {required String partnerName, required String urgeId}) {
  final l = AppLocalizations.of(context);
  return showReplySheet(context, title: l.reachingOut(partnerName), options: urgeReplies, urgeId: urgeId);
}

/// The partner posted an update (a slip): answer in prepared words.
Future<void> replyToUpdate(BuildContext context, {required String partnerName}) {
  final l = AppLocalizations.of(context);
  return showReplySheet(context, title: l.postedUpdate(partnerName), options: slipReplies);
}
