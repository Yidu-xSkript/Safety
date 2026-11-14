import 'dart:convert';

import '../../../core/kv.dart';
import '../domain/models.dart';

/// Whole solo state as one JSON string. Tiny by design (a few KB a year).
// ponytail: single blob in key-value storage. It stays the local source of truth; the pod outbox mirrors changes to the server.
class SoloStore {
  SoloStore(this._prefs);

  static const _key = 'anchor.solo.v1';
  final KV _prefs;

  SoloData load() {
    final raw = _prefs.get(_key);
    if (raw == null) return const SoloData();
    try {
      return SoloData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SoloData(); // a corrupt blob must not brick the app
    }
  }

  Future<void> save(SoloData data) => _prefs.set(_key, jsonEncode(data.toJson()));
}
