import 'package:flutter/services.dart';
import '../config/agent_config.dart';

class EnforcementChannel {
  static const _c = MethodChannel('accountability/enforce');

  Future<void> configure(AgentConfig cfg) => _c.invokeMethod('configure', {
        'dohUrl': cfg.nextDnsDohUrl,
        'botToken': cfg.telegramBotToken,
        'chatId': cfg.telegramChatId,
        'nextDnsApiKey': cfg.nextDnsApiKey ?? '',
        'nextDnsProfileId': cfg.nextDnsProfileId ?? '',
      });
  Future<bool> startVpn() async => await _c.invokeMethod('startVpn') as bool;
  Future<void> startWatchdog() => _c.invokeMethod('startWatchdog');
  Future<void> requestAdmin() => _c.invokeMethod('requestAdmin');
  Future<void> release() => _c.invokeMethod('release');
  Future<void> alertReleaseAttempt() => _c.invokeMethod('alertReleaseAttempt');
  Future<void> requestTelegramWatch() => _c.invokeMethod('requestTelegramWatch');
  Future<void> openAppInfo() => _c.invokeMethod('openAppInfo');
  Future<void> requestUsageAccess() => _c.invokeMethod('requestUsageAccess');
  Future<void> requestBatteryExemption() => _c.invokeMethod('requestBatteryExemption');

  // Posts a real test message to the Telegram channel. Returns null on success, or an error message.
  Future<String?> testReport() async => await _c.invokeMethod('testReport') as String?;

  // Real protection state: { 'vpn', 'admin', 'watchdog', 'telegramWatch' } → each true only if actually on.
  Future<Map<String, bool>> status() async {
    final r = await _c.invokeMethod('status');
    final m = Map<String, dynamic>.from(r as Map);
    return m.map((k, v) => MapEntry(k, v == true));
  }
}
