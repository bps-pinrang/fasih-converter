import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/services/fasih_gcm_decryptor.dart';
import 'package:pointycastle/export.dart';

void main() {
  // Produces a (wrappedDataKeyB64, encryptedB64, plaintext) triple using the
  // same algorithm CryptoGCM uses, so the test is self-contained.
  (String, String, String) makeVector({String plain = '{"answers":[]}'}) {
    final key = Uint8List(16)..fillRange(0, 16, 0x42);
    final iv = Uint8List(12)..fillRange(0, 12, 0x01);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final ct = cipher.process(Uint8List.fromList(utf8.encode(plain)));

    final payload = Uint8List(12 + ct.length)
      ..setRange(0, 12, iv)
      ..setRange(12, 12 + ct.length, ct);

    return (
      base64.encode(key),
      base64.encode(payload),
      plain,
    );
  }

  test('decrypts GCM payload produced by CryptoGCM', () {
    final (wrappedKey, encrypted, expected) = makeVector();
    expect(
        FasihGcmDecryptor.tryDecrypt(encrypted, wrappedKey), equals(expected));
  });

  test('decrypts 24-byte key', () {
    final key = Uint8List(24)..fillRange(0, 24, 0x33);
    final iv = Uint8List(12)..fillRange(0, 12, 0x02);
    const plain = 'hello';

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final ct = cipher.process(Uint8List.fromList(utf8.encode(plain)));

    final payload = Uint8List(12 + ct.length)
      ..setRange(0, 12, iv)
      ..setRange(12, 12 + ct.length, ct);

    expect(
      FasihGcmDecryptor.tryDecrypt(base64.encode(payload), base64.encode(key)),
      equals(plain),
    );
  });

  test('returns null on tampered ciphertext (bad GCM tag)', () {
    final (wrappedKey, encrypted, _) = makeVector();
    final bytes = base64.decode(encrypted);
    bytes[bytes.length - 1] ^= 0xFF; // flip last byte of GCM tag
    expect(
        FasihGcmDecryptor.tryDecrypt(base64.encode(bytes), wrappedKey), isNull);
  });

  test('returns null for invalid key length (7 bytes)', () {
    expect(
      FasihGcmDecryptor.tryDecrypt('dGVzdA==', base64.encode(Uint8List(7))),
      isNull,
    );
  });

  test('returns null for payload shorter than iv+tag (27 bytes min)', () {
    final key = base64.encode(Uint8List(16)..fillRange(0, 16, 0x01));
    // 11 bytes — too short even for IV
    expect(
      FasihGcmDecryptor.tryDecrypt(base64.encode(Uint8List(11)), key),
      isNull,
    );
  });
}
