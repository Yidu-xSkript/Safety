import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kv.dart';
import '../../core/reminders.dart';
import '../../l10n/app_localizations.dart';
import '../urge/contact.dart' show kPartnerPhoneKey;
import '../today/solo_controller.dart';

const kReminderKey = 'anchor.reminder'; // 'off' or 'HH:MM'
const kSecureDismissedKey = 'anchor.secure.dismissed';

/// Everything the Pod tab lets you change. All of it lives on this phone only.
class Settings {
  const Settings({this.reminder, this.partnerPhone, this.secureDismissed = 0});

  final TimeOfDay? reminder; // null = off
  final String? partnerPhone; // never leaves the device
  final int secureDismissed; // the "secure your pod" card is shown at most twice
}

class SettingsController extends AsyncNotifier<Settings> {
  late KV _kv;

  @override
  Future<Settings> build() async {
    _kv = await ref.watch(kvProvider.future);
    final r = _kv.get(kReminderKey);
    TimeOfDay? reminder;
    if (r != null && r.contains(':')) {
      final p = r.split(':');
      reminder = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    final phone = _kv.get(kPartnerPhoneKey);
    return Settings(
      reminder: reminder,
      partnerPhone: phone == null || phone.isEmpty ? null : phone,
      secureDismissed: int.tryParse(_kv.get(kSecureDismissedKey) ?? '') ?? 0,
    );
  }

  Settings get _s => state.requireValue;

  Future<void> setReminder(TimeOfDay? t) async {
    await _kv.set(kReminderKey, t == null ? 'off' : '${t.hour}:${t.minute}');
    state = AsyncData(Settings(reminder: t, partnerPhone: _s.partnerPhone, secureDismissed: _s.secureDismissed));
  }

  /// Empty or null removes it.
  Future<void> setPartnerPhone(String? phone) async {
    final clean = phone?.trim() ?? '';
    await _kv.set(kPartnerPhoneKey, clean);
    state = AsyncData(Settings(reminder: _s.reminder, partnerPhone: clean.isEmpty ? null : clean, secureDismissed: _s.secureDismissed));
  }

  Future<void> dismissSecure() async {
    final n = _s.secureDismissed + 1;
    await _kv.set(kSecureDismissedKey, '$n');
    state = AsyncData(Settings(reminder: _s.reminder, partnerPhone: _s.partnerPhone, secureDismissed: n));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, Settings>(SettingsController.new);

/// "Not now" on the secure card hides it for the rest of this session; the counter in [Settings] limits it to two sessions in all.
class _SecureHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void hide() => state = true;
}

final secureHiddenProvider = NotifierProvider<_SecureHidden, bool>(_SecureHidden.new);

/// Keeps the scheduled reminder in step with the setting and with whether today's check-in is already done.
/// Rebuilt on every change and on app resume (which also re-anchors it after a daylight-saving change).
final reminderSyncProvider = Provider<void>((ref) {
  final at = ref.watch(settingsProvider.select((s) => s.value?.reminder));
  final day = ref.watch(soloProvider.select((s) => s.value == null ? null : (s.value!.today, s.value!.pledge != null)));
  if (day == null) return;
  // ponytail: English until the app is localised (the scheduler has no BuildContext).
  final l = lookupAppLocalizations(const Locale('en'));
  ref.read(reminderServiceProvider).sync(at, skipToday: day.$2, title: l.appName, body: l.reminderBody);
});
