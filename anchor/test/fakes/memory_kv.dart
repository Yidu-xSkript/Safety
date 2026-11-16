import 'package:anchor/core/kv.dart';

/// One phone's storage. Two of these let a test run two phones side by side.
class MemoryKV implements KV {
  final values = <String, String>{};

  @override
  String? get(String key) => values[key];

  @override
  Future<void> set(String key, String value) async => values[key] = value;

  @override
  Future<void> clear() async => values.clear();
}
