// More platform-native pieces: a grouped settings list, a confirm dialog, a time picker.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'adaptive_page.dart';

/// One row of a settings list. [onTap] makes it tappable (chevron on iOS); [trailing] replaces the chevron.
class SettingsRow {
  const SettingsRow({required this.title, this.subtitle, this.trailing, this.onTap, this.destructive = false});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
}

/// A grouped list: inset grouped section on iOS, a tonal card with dividers on Android.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.rows});

  final List<SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isIOS(context)) {
      return CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        children: [
          for (final r in rows)
            CupertinoListTile(
              title: Text(r.title, style: TextStyle(color: r.destructive ? scheme.error : null)),
              subtitle: r.subtitle == null ? null : Text(r.subtitle!),
              trailing: r.trailing ?? (r.onTap != null && !r.destructive ? const CupertinoListTileChevron() : null),
              onTap: r.onTap,
            ),
        ],
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant),
            ListTile(
              minTileHeight: 56,
              title: Text(rows[i].title, style: TextStyle(color: rows[i].destructive ? scheme.error : null)),
              subtitle: rows[i].subtitle == null ? null : Text(rows[i].subtitle!),
              trailing: rows[i].trailing,
              onTap: rows[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}

/// A decision that must interrupt (leaving a pod). The platform's own alert; destructive styling when [destructive].
Future<bool> adaptiveConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final l = AppLocalizations.of(context);
  Widget action(BuildContext ctx, String label, bool value, {bool danger = false}) => isIOS(ctx)
      ? CupertinoDialogAction(isDestructiveAction: danger, isDefaultAction: !danger && value, onPressed: () => Navigator.of(ctx).pop(value), child: Text(label))
      : TextButton(
          onPressed: () => Navigator.of(ctx).pop(value),
          style: danger ? TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error) : null,
          child: Text(label),
        );
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(body),
      actions: [action(ctx, l.cancel, false), action(ctx, confirmLabel, true, danger: destructive)],
    ),
  );
  return ok ?? false;
}

/// A time of day: Material's dial on Android, the wheel on iOS. Null when dismissed.
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) async {
  if (!isIOS(context)) return showTimePicker(context: context, initialTime: initial);
  final l = AppLocalizations.of(context);
  var picked = initial;
  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (ctx) => CupertinoPopupSurface(
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(onPressed: () => Navigator.of(ctx).pop(picked), child: Text(l.done)),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(2026, 1, 1, initial.hour, initial.minute),
                onDateTimeChanged: (d) => picked = TimeOfDay(hour: d.hour, minute: d.minute),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
