import 'package:flutter/services.dart';
import '../config/agent_config.dart';

class EnforcementChannel {
  static const _c = MethodChannel('accountability/enforce');

  Future<void> configure(AgentConfig cfg) => _c.invokeMethod('configure', {
        'dohUrl': cfg.nextDnsDohUrl,
        'witnessEmail': cfg.witnessEmail,
        'smtpHost': cfg.smtp!.host, 'smtpPort': cfg.smtp!.port,
        'smtpUser': cfg.smtp!.username, 'smtpPass': cfg.smtp!.appPassword,
        'smtpFrom': cfg.smtp!.fromAddress,
      });
  Future<bool> startVpn() async => await _c.invokeMethod('startVpn') as bool;
  Future<void> startWatchdog() => _c.invokeMethod('startWatchdog');
  Future<void> requestAdmin() => _c.invokeMethod('requestAdmin');
  Future<void> release() => _c.invokeMethod('release');
  Future<void> alertReleaseAttempt() => _c.invokeMethod('alertReleaseAttempt');

  // Real protection state: { 'vpn', 'admin', 'watchdog' } → each true only if actually on.
  Future<Map<String, bool>> status() async {
    final r = await _c.invokeMethod('status');
    final m = Map<String, dynamic>.from(r as Map);
    return m.map((k, v) => MapEntry(k, v == true));
  }
}
