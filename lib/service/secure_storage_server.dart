import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A thin wrapper over FlutterSecureStorage to standardize
/// secure key-value operations and byte convenience helpers.
abstract class SecureStorageServer {
  Future<void> writeString({required String key, required String value});

  Future<String?> readString({required String key});

  Future<void> delete({required String key});

  Future<void> writeBytes({required String key, required Uint8List value});

  Future<Uint8List?> readBytes({required String key});
}

class SecureStorageServerImpl implements SecureStorageServer {
  SecureStorageServerImpl()
      : _storage = const FlutterSecureStorage(),
        _ios = const IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          synchronizable: true,
        ),
        _android = const AndroidOptions(
          encryptedSharedPreferences: true,
        );

  final FlutterSecureStorage _storage;
  final IOSOptions _ios;
  final AndroidOptions _android;

  @override
  Future<void> writeString({required String key, required String value}) async {
    await _storage.write(
      key: key,
      value: value,
      iOptions: _ios,
      aOptions: _android,
    );
  }

  @override
  Future<String?> readString({required String key}) {
    return _storage.read(
      key: key,
      iOptions: _ios,
      aOptions: _android,
    );
  }

  @override
  Future<void> delete({required String key}) async {
    await _storage.delete(
      key: key,
      iOptions: _ios,
      aOptions: _android,
    );
  }

  @override
  Future<void> writeBytes({required String key, required Uint8List value}) {
    return writeString(key: key, value: base64Encode(value));
  }

  @override
  Future<Uint8List?> readBytes({required String key}) async {
    final s = await readString(key: key);
    if (s == null) return null;
    return Uint8List.fromList(base64Decode(s));
  }
}
