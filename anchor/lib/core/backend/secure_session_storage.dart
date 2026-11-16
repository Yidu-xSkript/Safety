import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show LocalStorage;

/// The Supabase session (what proves "this is the same person") lives in the Keychain / Android Keystore, not in
/// plain preferences. NOT yet exercised on a device.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();

  static const _key = 'anchor.supabase.session';
  static const _store = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _store.read(key: _key)) != null;

  @override
  Future<String?> accessToken() => _store.read(key: _key);

  @override
  Future<void> removePersistedSession() => _store.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) => _store.write(key: _key, value: persistSessionString);
}
