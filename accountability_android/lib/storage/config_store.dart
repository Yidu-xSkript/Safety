import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/agent_config.dart';

class ConfigStore {
  final FlutterSecureStorage _s;
  ConfigStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  Future<void> saveConfig(AgentConfig c) => _s.write(key: 'config', value: jsonEncode(c.toJson()));
  Future<AgentConfig?> loadConfig() async {
    final raw = await _s.read(key: 'config');
    return raw == null ? null : AgentConfig.fromJson(jsonDecode(raw));
  }

  Future<void> savePinHash(String hash) => _s.write(key: 'pinHash', value: hash);
  Future<String?> loadPinHash() => _s.read(key: 'pinHash');
}
