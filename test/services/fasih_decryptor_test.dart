import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/services/fasih_decryptor.dart';
import 'package:pointycastle/export.dart';

/// Encrypts [plaintext] using the same algorithm FASIH uses, so we have a
/// known ciphertext to verify against.
String _fasihEncrypt(String plaintext) {
  const key = 'Z!,vDKUPv;.Jy0Q4Eq1wVCY-a_!GnT';
  const iterations = 11000;

  // Random-looking but deterministic salt/IV for tests
  final saltRaw = Uint8List.fromList(List.generate(32, (i) => i + 1));
  final iv = Uint8List.fromList(List.generate(16, (i) => i + 33));

  // Replicate FASIH's UTF-8 round-trip on the salt
  final saltBytes = Uint8List.fromList(
    utf8.encode(utf8.decode(saltRaw, allowMalformed: true)),
  );

  // PKCS#12 key derivation with SHA-256
  final passwordBytes = _formatPkcs12Password(key.codeUnits);
  final gen = PKCS12ParametersGenerator(SHA256Digest())
    ..init(passwordBytes, saltBytes, iterations);
  final derivedKey = gen.generateDerivedParameters(32).key;

  // AES/CBC/PKCS7Padding encrypt
  final cipher = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(derivedKey), iv));

  final input = Uint8List.fromList(utf8.encode(plaintext));
  final padded = _pkcs7Pad(input, 16);
  final ciphertext = Uint8List(padded.length);
  int offset = 0;
  while (offset < padded.length) {
    offset += cipher.processBlock(padded, offset, ciphertext, offset);
  }

  // SHA-256 digest of ciphertext
  final digest = SHA256Digest().process(ciphertext);

  // Format: base64(cipher)#base64(sha256)#base64(salt)#base64(iv)
  return '${base64.encode(ciphertext)}#${base64.encode(digest)}#${base64.encode(saltRaw)}#${base64.encode(iv)}';
}

Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
  final padLen = blockSize - (data.length % blockSize);
  return Uint8List(data.length + padLen)
    ..setAll(0, data)
    ..fillRange(data.length, data.length + padLen, padLen);
}

Uint8List _formatPkcs12Password(List<int> codeUnits) {
  if (codeUnits.isEmpty) return Uint8List(0);
  final out = Uint8List((codeUnits.length + 1) * 2);
  for (int i = 0; i < codeUnits.length; i++) {
    out[i * 2] = (codeUnits[i] >> 8) & 0xFF;
    out[i * 2 + 1] = codeUnits[i] & 0xFF;
  }
  return out;
}

void main() {
  group('FasihDecryptor.tryDecrypt', () {
    test('decrypts a round-trip encrypted payload', () {
      const plaintext = '{"templateId":"abc","answers":[]}';
      final encrypted = _fasihEncrypt(plaintext);
      final result = FasihDecryptor.tryDecrypt(encrypted);
      expect(result, plaintext);
    });

    test('returns null for plain JSON (not encrypted)', () {
      const json = '{"answers":[]}';
      expect(FasihDecryptor.tryDecrypt(json), isNull);
    });

    test('returns null for random garbage', () {
      expect(FasihDecryptor.tryDecrypt('not#valid#data#here'), isNull);
    });

    test('returns null when fewer than 4 parts', () {
      expect(FasihDecryptor.tryDecrypt('abc#def#ghi'), isNull);
    });

    test('returns null when SHA-256 integrity check fails', () {
      const plaintext = '{"answers":[]}';
      final encrypted = _fasihEncrypt(plaintext);
      // Corrupt the ciphertext (first segment)
      final parts = encrypted.split('#');
      final corruptedCipher = base64.encode(
        Uint8List.fromList(base64.decode(parts[0])..last ^= 0xFF),
      );
      final corrupted = [corruptedCipher, ...parts.sublist(1)].join('#');
      expect(FasihDecryptor.tryDecrypt(corrupted), isNull);
    });

    test('decrypts payload containing survey answers', () {
      const plaintext =
          '{"templateId":"21f36ba5","templateDataKey":"VHTS_2026","answers":['
          '{"dataKey":"r101","answer":"Ahmad"},'
          '{"dataKey":"r102","answer":"35"}'
          ']}';
      final encrypted = _fasihEncrypt(plaintext);
      final decrypted = FasihDecryptor.tryDecrypt(encrypted);
      expect(decrypted, plaintext);
    });
  });
}
