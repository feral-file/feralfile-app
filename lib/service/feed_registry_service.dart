import 'dart:convert';
import 'dart:typed_data';

import 'package:autonomy_flutter/service/secure_storage_server.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:cryptography/cryptography.dart';
import 'package:fast_base58/fast_base58.dart';

abstract class FeedRegistryService {
  FeedRegistryService();

  Future<void> starPlaylist(PlaylistReference playlistReference);

  Future<void> unstarPlaylist(PlaylistReference playlistReference);

  // FR1.1: ECDSA (P-256) Key lifecycle
  Future<void> ensureUserEcdsaKeypair();

  Future<Uint8List> getEcdsaPublicKey();

  Future<String> getUserDid();

  Future<Uint8List> signWithUserKey(Uint8List message);
}

class FeedRegistryServiceImpl extends FeedRegistryService {
  FeedRegistryServiceImpl() : _secureStorage = SecureStorageServerImpl();

  // Key names in platform secure storage (ECDSA P-256)
  static const String _kPrivKey = 'ff.ecdsa.p256.privateKey';
  static const String _kPubKey = 'ff.ecdsa.p256.publicKey';
  static const String _kDid = 'ff.ecdsa.p256.did';

  final SecureStorageServer _secureStorage;

  // ECDSA P-256 implementation
  final Ecdsa _ecdsa = Ecdsa.p256(Sha256());

  // Platform-specific secure options are encapsulated inside SecureStorageServer

  @override
  Future<void> starPlaylist(PlaylistReference playlistReference) async {
    await Future.delayed(const Duration(seconds: 3), () {
      print('starPlaylist: ${playlistReference.playlist.title}');
    });
  }

  @override
  Future<void> unstarPlaylist(PlaylistReference playlistReference) async {
    Future.delayed(const Duration(seconds: 3), () {
      print('unstarPlaylist: ${playlistReference.playlist.title}');
    });
  }

  // ----- FR1.1: ECDSA P-256 Key Generation, Storage, Sync, DID -----

  @override
  Future<void> ensureUserEcdsaKeypair() async {
    final existingPriv = await _secureStorage.readString(key: _kPrivKey);
    final existingPub = await _secureStorage.readString(key: _kPubKey);
    if (existingPriv != null && existingPub != null) {
      // Ensure DID cached and synced
      await _ensureDidAndSync();
      return;
    }

    // Generate new ECDSA P-256 keypair
    final keyPair = await _ecdsa.newKeyPair();
    final privateKeyBytes = await _extractEcPrivateKeyBytes(keyPair);
    final publicKeyBytes = await _extractEcUncompressedPublicKeyBytes(keyPair);

    // Store in platform secure storage (iOS synchronizable => iCloud Keychain)
    await _secureStorage.writeString(
        key: _kPrivKey, value: base64Encode(privateKeyBytes));
    await _secureStorage.writeString(
        key: _kPubKey, value: base64Encode(publicKeyBytes));

    // Derive DID and cache
    final did = _deriveDidFromP256PublicKey(Uint8List.fromList(publicKeyBytes));
    await _secureStorage.writeString(key: _kDid, value: did);

    // Do not sync to cloud. Public materials remain local.
  }

  @override
  Future<Uint8List> getEcdsaPublicKey() async {
    final value = await _secureStorage.readString(key: _kPubKey);
    if (value != null) {
      return Uint8List.fromList(base64Decode(value));
    }
    // If not found, throw an error
    throw FeedRegistryServicePublicKeyNotFoundException();
  }

  @override
  Future<String> getUserDid() async {
    final existing = await _secureStorage.readString(key: _kDid);
    if (existing != null) {
      return existing;
    }
    // Derive from public key and persist
    final pub = await getEcdsaPublicKey();
    final did = _deriveDidFromP256PublicKey(pub);
    await _secureStorage.writeString(key: _kDid, value: did);
    return did;
  }

  @override
  Future<Uint8List> signWithUserKey(Uint8List message) async {
    final privB64 = await _secureStorage.readString(key: _kPrivKey);
    final pub = await getEcdsaPublicKey();
    if (privB64 == null) {
      await ensureUserEcdsaKeypair();
      final privAfterInit = await _secureStorage.readString(key: _kPrivKey);
      if (privAfterInit == null) {
        throw StateError('Failed to initialize ECDSA private key');
      }
      final privateKeyBytes = Uint8List.fromList(base64Decode(privAfterInit));
      final publicKey = SimplePublicKey(pub, type: KeyPairType.p256);
      final keyPair = SimpleKeyPairData(
        privateKeyBytes,
        publicKey: publicKey,
        type: KeyPairType.p256,
      );
      final signature = await _ecdsa.sign(message, keyPair: keyPair);
      return Uint8List.fromList(signature.bytes);
    }
    final privateKeyBytes = Uint8List.fromList(base64Decode(privB64));
    final publicKey = SimplePublicKey(pub, type: KeyPairType.p256);
    final keyPair = SimpleKeyPairData(
      privateKeyBytes,
      publicKey: publicKey,
      type: KeyPairType.p256,
    );
    final signature = await _ecdsa.sign(message, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  Future<void> _ensureDidAndSync() async {
    final did = await _secureStorage.readString(key: _kDid);
    if (did != null) {
      return;
    }
    final pub = await getEcdsaPublicKey();
    final derived = _deriveDidFromP256PublicKey(pub);
    await _secureStorage.writeString(key: _kDid, value: derived);
  }

  // DID key derivation per did:key using multicodec and multibase base58btc
  // For P-256, multicodec code is 0x1200 -> uvarint bytes [0x80, 0x24]
  // DID = 'did:key:' + 'z' + base58btc( [0x80,0x24] + publicKey )
  String _deriveDidFromP256PublicKey(Uint8List publicKey) {
    final multicodecPrefixed = Uint8List(publicKey.length + 2)
      ..[0] = 0x80
      ..[1] = 0x24;
    multicodecPrefixed.setRange(2, multicodecPrefixed.length, publicKey);
    final b58 = Base58Encode(multicodecPrefixed);
    return 'did:key:z$b58';
  }

  // Helpers for ECDSA P-256 serialization
  Future<Uint8List> _extractEcUncompressedPublicKeyBytes(
      KeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    if (publicKey is EcPublicKey) {
      final x = publicKey.x; // List<int> or bytes of X coordinate
      final y = publicKey.y; // List<int> or bytes of Y coordinate
      final xBytes = _padTo32Bytes(x);
      final yBytes = _padTo32Bytes(y);
      // Uncompressed point format: 0x04 || X || Y
      final result = Uint8List(1 + 32 + 32);
      result[0] = 0x04;
      result.setRange(1, 33, xBytes);
      result.setRange(33, 65, yBytes);
      return result;
    }
    // Fallback: try to use SimplePublicKey.bytes if present
    if (publicKey is SimplePublicKey) {
      return Uint8List.fromList(publicKey.bytes);
    }
    throw StateError('Unsupported public key type for ECDSA P-256');
  }

  Future<Uint8List> _extractEcPrivateKeyBytes(KeyPair keyPair) async {
    final extracted = await keyPair.extract();
    if (extracted is SimpleKeyPairData) {
      return Uint8List.fromList(extracted.bytes);
    }
    throw StateError('Unsupported private key type for ECDSA P-256');
  }

  Uint8List _padTo32Bytes(List<int> value) {
    if (value.length == 32) return Uint8List.fromList(value);
    if (value.length > 32) {
      // take the last 32 bytes (most significant trimmed if needed)
      return Uint8List.fromList(value.sublist(value.length - 32));
    }
    final result = Uint8List(32);
    // left pad with zeros
    result.setRange(32 - value.length, 32, value);
    return result;
  }
}

class FeedRegistryServiceException implements Exception {
  FeedRegistryServiceException(this.message);

  final String message;
}

class FeedRegistryServicePublicKeyNotFoundException
    extends FeedRegistryServiceException {
  FeedRegistryServicePublicKeyNotFoundException()
      : super('Public key not found');
}

class FeedRegistryServicePrivateKeyNotFoundException
    extends FeedRegistryServiceException {
  FeedRegistryServicePrivateKeyNotFoundException()
      : super('Private key not found');
}

class FeedRegistryServiceDidNotFoundException
    extends FeedRegistryServiceException {
  FeedRegistryServiceDidNotFoundException() : super('DID not found');
}
