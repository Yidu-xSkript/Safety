import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/adaptive_extras.dart';
import '../../core/adaptive/adaptive_page.dart';
import '../../core/adaptive/adaptive_widgets.dart';
import '../../core/reminders.dart';
import '../../l10n/app_localizations.dart';
import '../urge/urge_screen.dart' show kShowCrisisResources;
import 'account_controller.dart';
import 'domain/care.dart';
import 'email_flow.dart';
import 'pod_controller.dart';
import 'push_controller.dart';
import 'settings_controller.dart';

/// Everything about the two of you and this phone, as one plain list. Nothing here is shown to your partner,
/// except leaving, which they are told about.
class PodPage extends ConsumerStatefulWidget {
  const PodPage({super.key, required this.onUrge});

  final VoidCallback onUrge;

  @override
  ConsumerState<PodPage> createState() => _PodPageState();
}

class _PodPageState extends ConsumerState<PodPage> {
  bool _reminderDenied = false;

  Future<void> _toggleReminder(bool on) async {
    final settings = ref.read(settingsProvider.notifier);
    if (!on) {
      setState(() => _reminderDenied = false);
      return settings.setReminder(null);
    }
    final ok = await ref.read(reminderServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() => _reminderDenied = !ok);
    if (ok) await settings.setReminder(const TimeOfDay(hour: kDefaultReminderHour, minute: kDefaultReminderMinute));
  }

  Future<void> _pickTime(TimeOfDay current) async {
    final t = await pickTime(context, current);
    if (t != null) await ref.read(settingsProvider.notifier).setReminder(t);
  }

  Future<void> _leave(String partner) async {
    final l = AppLocalizations.of(context);
    final ok = await adaptiveConfirm(context, title: l.leaveTitle, body: l.leaveBody(partner), confirmLabel: l.settingsLeave, destructive: true);
    if (ok) await ref.read(podProvider.notifier).leavePod();
  }

  Future<void> _editNumber(String partner, String? current) async {
    final result = await adaptiveSheet<String>(context, (_) => _NumberSheet(partner: partner, current: current));
    if (result != null) await ref.read(settingsProvider.notifier).setPartnerPhone(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final pod = ref.watch(podProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final push = ref.watch(pushProvider).value;
    final account = ref.watch(accountProvider).value;
    final loc = MaterialLocalizations.of(context);
    final partner = pod?.pod?.partnerName ?? '';
    final reminder = settings?.reminder;
    final ios = isIOS(context);

    final reminderSwitch = ios
        ? CupertinoSwitch(value: reminder != null, onChanged: _toggleReminder)
        : Switch(value: reminder != null, onChanged: _toggleReminder);

    return AdaptivePage(
      title: l.tabPod,
      onUrge: widget.onUrge,
      children: [
        if (pod?.pod != null) ...[
          SettingsSection(rows: [SettingsRow(title: l.settingsPartner, subtitle: partner)]),
          const SizedBox(height: 16),
        ],
        SettingsSection(rows: [
          SettingsRow(
            title: l.settingsReminder,
            subtitle: _reminderDenied
                ? l.reminderDenied
                : reminder == null
                    ? l.reminderOff
                    : loc.formatTimeOfDay(reminder, alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context)),
            trailing: reminderSwitch,
            onTap: reminder == null ? null : () => _pickTime(reminder),
          ),
          if (pod?.pod != null)
            SettingsRow(
              title: l.settingsPartnerNumber,
              subtitle: settings?.partnerPhone ?? l.partnerNumberNone,
              onTap: () => _editNumber(partner, settings?.partnerPhone),
            ),
          if (push != null && push.supported)
            SettingsRow(
              title: l.settingsNotifications,
              subtitle: push.enabled ? l.on : l.off,
              trailing: push.enabled ? null : AdaptiveButton(label: l.turnOn, kind: ButtonKind.text, onPressed: () => ref.read(pushProvider.notifier).enable()),
            ),
        ]),
        if (pod?.pod != null) ...[
          const SizedBox(height: 16),
          SettingsSection(rows: [
            SettingsRow(
              title: l.settingsSecure,
              subtitle: account?.secured ?? false ? l.secured(account!.email!) : l.secureSubtitle,
              onTap: account?.secured ?? false ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SecureScreen())),
            ),
            if (kShowCrisisResources) SettingsRow(title: l.urgeHelp, onTap: () {}),
            SettingsRow(title: l.settingsLeave, destructive: true, onTap: () => _leave(partner)),
          ]),
        ],
        const SizedBox(height: 24),
        Text(l.notTreatment, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// The partner's number, saved on this phone only. Owns its text controller so it is disposed with the sheet,
/// after the closing animation, never before.
class _NumberSheet extends StatefulWidget {
  const _NumberSheet({required this.partner, required this.current});

  final String partner;
  final String? current;

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late final _c = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _c.dispose();
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
          Text(l.settingsPartnerNumber, style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(l.partnerNumberHelp(widget.partner), style: t.bodyLarge),
          const SizedBox(height: 16),
          AdaptiveTextField(controller: _c, hint: l.partnerNumberHint, keyboardType: TextInputType.phone, autofocus: true),
          const SizedBox(height: 16),
          AdaptiveButton(label: l.save, expand: true, onPressed: () => Navigator.of(context).pop(_c.text)),
          if (widget.current != null) AdaptiveButton(label: l.remove, kind: ButtonKind.text, onPressed: () => Navigator.of(context).pop('')),
        ],
      ),
    );
  }
}
