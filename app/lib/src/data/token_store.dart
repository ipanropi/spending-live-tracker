import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the Wise token in the platform's secure storage: Android Keystore,
/// Windows Credential Manager, macOS Keychain.
class TokenStore {
  const TokenStore();

  static const String _key = 'wise_token';

  // On macOS, the legacy keychain avoids the Keychain Sharing entitlement, which
  // would tie an unsigned build to the Mac that built it. Other platforms ignore this.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<String?> read() async {
    try {
      final token = await _storage.read(key: _key);
      return (token == null || token.isEmpty) ? null : token;
    } on Exception {
      return null; // unreadable storage behaves like "not connected yet"
    }
  }

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> delete() => _storage.delete(key: _key);
}
