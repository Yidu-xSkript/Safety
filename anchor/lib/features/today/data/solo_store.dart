import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// Whole solo state as one JSON string. Tiny by design (a few KB a year).
// ponytail: single blob in shared_preferences; Phase 2 replaces it with the Supabase repository + outbox.
class SoloStore {
  SoloStore(this._prefs);

  static const _key = 'anchor.solo.v1';
  final SharedPreferences _prefs;

  SoloData load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const SoloData();
    try {
      return SoloData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SoloData(); // a corrupt blob must not brick the app
    }
  }

  Future<void> save(SoloData data) => _prefs.setString(_key, jsonEncode(data.toJson()));
}
