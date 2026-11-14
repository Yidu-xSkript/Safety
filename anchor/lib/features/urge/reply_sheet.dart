import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/adaptive_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../pod/pod_controller.dart';
import 'contact.dart';
import 'replies.dart';

/// One tap sends a prepared reply and closes. [urgeId] ties it to their urge so it shows on their grounding screen.
Future<void> showReplySheet(
  BuildContext context, {
  required String title,
  required List<ReplyTemplate> options,
  String? urgeId,
}) =>
    adaptiveSheet<void>(context, (_) => _ReplySheet(title: title, options: options, urgeId: urgeId));

class _ReplySheet extends ConsumerStatefulWidget {
  const _ReplySheet({required this.title, required this.options, this.urgeId});

  final String title;
  final List<ReplyTemplate> options;
  final String? urgeId;

  @override
  ConsumerState<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<_ReplySheet> {
  bool _sent = false;
  Timer? _close;

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  void _send(ReplyTemplate t) {
    ref.read(podProvider.notifier).reply(t, urgeId: widget.urgeId);
    setState(() => _sent = true);
    _close = Timer(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    if (_sent) {
      return SizedBox(height: 160, child: Center(child: Text(l.replySent, style: t.headlineMedium)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: t.headlineMedium),
          const SizedBox(height: 16),
          for (var i = 0; i < widget.options.length; i++) ...[
            AdaptiveButton(
              label: replyText(l, widget.options[i]),
              kind: i == 0 ? ButtonKind.filled : ButtonKind.outlined,
              expand: true,
              onPressed: () => _send(widget.options[i]),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          const ContactButtons(),
        ],
      ),
    );
  }
}
