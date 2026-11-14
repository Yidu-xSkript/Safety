import 'package:flutter_test/flutter_test.dart';
import 'package:accountability_android/config/agent_config.dart';

void main() {
  group('AgentConfig', () {
    test('parses and validates a complete config', () {
      final c = AgentConfig.fromJson({
        'telegramBotToken': '123:abc',
        'telegramChatId': '@witness_channel',
        'nextDnsDohUrl': 'https://dns.nextdns.io/abc123',
      });
      expect(c.telegramChatId, '@witness_channel');
      expect(c.isValid, true);
    });

    test('is invalid when the Telegram bot token or channel is missing', () {
      final c = AgentConfig.fromJson({'nextDnsDohUrl': 'https://dns.nextdns.io/abc'});
      expect(c.isValid, false);
      expect(c.validationErrors, contains('telegramBotToken is required'));
      expect(c.validationErrors, contains('telegramChatId is required'));
    });

    test('round-trips through toJson', () {
      final j = {
        'telegramBotToken': '123:abc',
        'telegramChatId': '-1001234567890',
        'nextDnsDohUrl': 'https://dns.nextdns.io/abc123',
      };
      expect(AgentConfig.fromJson(j).toJson(), j);
    });
  });
}
