import 'package:flutter/material.dart';

import '../../../core/adaptive/adaptive_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// Result of the slip sheet: the (possibly empty) note when saved, or null when dismissed with "Not yet".
/// Never red, never alarmed: the first thing it says is thank you.
Future<String?> showSlipSheet(BuildContext context, {String? initialNote}) =>
    adaptiveSheet<String>(context, (_) => _SlipSheet(initialNote: initialNote));

class _SlipSheet extends StatefulWidget {
  const _SlipSheet({this.initialNote});

  final String? initialNote;

  @override
  State<_SlipSheet> createState() => _SlipSheetState();
}

class _SlipSheetState extends State<_SlipSheet> {
  late final _note = TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.slipTitle, style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(l.slipBody, style: t.bodyLarge),
          const SizedBox(height: 16),
          AdaptiveTextField(controller: _note, hint: l.slipNoteHint, maxLength: 500, maxLines: 4),
          const SizedBox(height: 16),
          AdaptiveButton(label: l.slipSave, expand: true, onPressed: () => Navigator.of(context).pop(_note.text.trim())),
          AdaptiveButton(label: l.slipNotYet, kind: ButtonKind.text, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
