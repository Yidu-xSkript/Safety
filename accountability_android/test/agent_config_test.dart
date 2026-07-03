import 'package:flutter_test/flutter_test.dart';
import 'package:accountability_android/config/agent_config.dart';

void main() {
  group('AgentConfig', () {
    test('parses and validates a complete config', () {
      final c = AgentConfig.fromJson({
        'witnessEmail': 'w@x.com',
        'nextDnsDohUrl': 'https://dns.nextdns.io/abc123',
        'smtp': {'host': 's', 'port': 587, 'username': 'u', 'appPassword': 'p', 'fromAddress': 'f@x.com'},
      });
      expect(c.witnessEmail, 'w@x.com');
      expect(c.isValid, true);
    });

    test('is invalid when the witness email is missing', () {
      final c = AgentConfig.fromJson({'nextDnsDohUrl': 'https://dns.nextdns.io/abc'});
      expect(c.isValid, false);
      expect(c.validationErrors, contains('witnessEmail is required'));
    });

    test('round-trips through toJson', () {
      final j = {
        'witnessEmail': 'w@x.com',
        'nextDnsDohUrl': 'https://dns.nextdns.io/abc123',
        'smtp': {'host': 's', 'port': 587, 'username': 'u', 'appPassword': 'p', 'fromAddress': 'f@x.com'},
      };
      expect(AgentConfig.fromJson(j).toJson(), j);
    });
  });
}
