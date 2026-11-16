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
const kAppLockKey = 'anchor.applock'; // absent = default (on when the phone can lock), 'on', 'off'
const kHideKey = 'anchor.hide'; // absent = default (on), 'on', 'off'

/// Everything the Pod tab lets you change. All of it lives on this phone only.
class Settings {
  const Settings({
    this.reminder,
    this.partnerPhone,
    this.secureDismissed = 0,
    this.appLock,
    this.hideInSwitcher = true,
  });

  final TimeOfDay? reminder; // null = off
  final String? partnerPhone; // never leaves the device
  final int secureDismissed; // the "secure your pod" card is shown at most twice

  /// null = never chosen: the lock is on whenever this phone can lock (docs/SECURITY.md).
  final bool? appLock;

  /// Cover the app in the app switcher (and, on Android, block screenshots). On unless turned off.
  final bool hideInSwitcher;

  Settings copyWith({
    TimeOfDay? reminder,
    bool clearReminder = false,
    String? partnerPhone,
    bool clearPhone = false,
    int? secureDismissed,
    bool? appLock,
    bool? hideInSwitcher,
  }) =>
      Settings(
        reminder: clearReminder ? null : (reminder ?? this.reminder),
        partnerPhone: clearPhone ? null : (partnerPhone ?? this.partnerPhone),
        secureDismissed: secureDismissed ?? this.secureDismissed,
        appLock: appLock ?? this.appLock,
        hideInSwitcher: hideInSwitcher ?? this.hideInSwitcher,
      );
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
    final lock = _kv.get(kAppLockKey);
    return Settings(
      reminder: reminder,
      partnerPhone: phone == null || phone.isEmpty ? null : phone,
      secureDismissed: int.tryParse(_kv.get(kSecureDismissedKey) ?? '') ?? 0,
      appLock: lock == null ? null : lock == 'on',
      hideInSwitcher: _kv.get(kHideKey) != 'off',
    );
  }

  Settings get _s => state.requireValue;

  Future<void> setReminder(TimeOfDay? t) async {
    await _kv.set(kReminderKey, t == null ? 'off' : '${t.hour}:${t.minute}');
    state = AsyncData(t == null ? _s.copyWith(clearReminder: true) : _s.copyWith(reminder: t));
  }

  /// Empty or null removes it.
  Future<void> setPartnerPhone(String? phone) async {
    final clean = phone?.trim() ?? '';
    await _kv.set(kPartnerPhoneKey, clean);
    state = AsyncData(clean.isEmpty ? _s.copyWith(clearPhone: true) : _s.copyWith(partnerPhone: clean));
  }

  Future<void> dismissSecure() async {
    final n = _s.secureDismissed + 1;
    await _kv.set(kSecureDismissedKey, '$n');
    state = AsyncData(_s.copyWith(secureDismissed: n));
  }

  Future<void> setAppLock(bool on) async {
    await _kv.set(kAppLockKey, on ? 'on' : 'off');
    state = AsyncData(_s.copyWith(appLock: on));
  }

  Future<void> setHideInSwitcher(bool on) async {
    await _kv.set(kHideKey, on ? 'on' : 'off');
    state = AsyncData(_s.copyWith(hideInSwitcher: on));
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
