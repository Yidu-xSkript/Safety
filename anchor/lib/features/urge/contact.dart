import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/adaptive/adaptive_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../pod/settings_controller.dart';

/// The partner's phone number lives only on this device (docs/SECURITY.md). Pod settings write it; with none saved,
/// Call/Text simply do not appear.
const kPartnerPhoneKey = 'anchor.partner_phone';

final partnerPhoneProvider = Provider<String?>((ref) => ref.watch(settingsProvider).value?.partnerPhone);

/// Overridden in tests so nothing really dials.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>((_) => launchUrl);

/// Call and Text, shown only when a number is saved. They open the phone's own dialer and messages.
class ContactButtons extends ConsumerWidget {
  const ContactButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(partnerPhoneProvider);
    if (phone == null || phone.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final open = ref.read(urlOpenerProvider);
    return Row(
      children: [
        Expanded(child: AdaptiveButton(label: l.urgeCall, kind: ButtonKind.outlined, onPressed: () => open(Uri(scheme: 'tel', path: phone)))),
        const SizedBox(width: 12),
        Expanded(child: AdaptiveButton(label: l.urgeText, kind: ButtonKind.outlined, onPressed: () => open(Uri(scheme: 'sms', path: phone)))),
      ],
    );
  }
}
