import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/services/fasih_encryption_helper.dart';
import 'package:pointycastle/export.dart';

// Builds a real GCM ciphertext so we can verify the GCM branch is actually taken.
(String encryptedB64, String wrappedKeyB64) _makeGcmPair(String plain) {
  final key = Uint8List(16)..fillRange(0, 16, 0x11);
  final iv = Uint8List(12)..fillRange(0, 12, 0x22);

  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final ct = cipher.process(Uint8List.fromList(utf8.encode(plain)));

  final payload = Uint8List(12 + ct.length)
    ..setRange(0, 12, iv)
    ..setRange(12, 12 + ct.length, ct);

  return (base64.encode(payload), base64.encode(key));
}

void main() {
  test('decrypts via GCM when valid wrappedDataKey provided', () {
    final (encrypted, wrappedKey) = _makeGcmPair('{"ok":true}');
    expect(
      FasihEncryptionHelper.tryDecrypt(encrypted, wrappedDataKey: wrappedKey),
      equals('{"ok":true}'),
    );
  });

  test('returns null when GCM payload is invalid and wrappedDataKey present',
      () {
    final wrappedKey = base64.encode(Uint8List(16)..fillRange(0, 16, 0x42));
    // Not a valid GCM ciphertext
    expect(
      FasihEncryptionHelper.tryDecrypt('notBase64!!!',
          wrappedDataKey: wrappedKey),
      isNull,
    );
  });

  test('routes to legacy when wrappedDataKey is null', () {
    // Legacy format; invalid → null (no crash)
    expect(
      FasihEncryptionHelper.tryDecrypt(
        'notvalid#notvalid#notvalid#notvalid',
        wrappedDataKey: null,
      ),
      isNull,
    );
  });

  test('routes to legacy when wrappedDataKey is blank', () {
    expect(
      FasihEncryptionHelper.tryDecrypt(
        'notvalid#notvalid#notvalid#notvalid',
        wrappedDataKey: '   ',
      ),
      isNull,
    );
  });
}
