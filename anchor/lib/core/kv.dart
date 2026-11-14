import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tiny slice of storage the app needs: strings by key. Lets tests give each "phone" its own store.
abstract class KV {
  String? get(String key);
  Future<void> set(String key, String value);
}

class PrefsKV implements KV {
  PrefsKV(this._p);

  final SharedPreferences _p;

  @override
  String? get(String key) => _p.getString(key);

  @override
  Future<void> set(String key, String value) => _p.setString(key, value);
}

final kvProvider = FutureProvider<KV>((_) async => PrefsKV(await SharedPreferences.getInstance()));
