import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../core/env/app_env.dart';

/// Decrypts data.json files encrypted by FASIH's Kripto utility.
///
/// FASIH encrypts with AES/CBC/PKCS7Padding + PKCS#12 key derivation (SHA-256),
/// using a static application key and a per-file random salt/IV.
/// Encrypted content format: base64(cipher)#base64(sha256)#base64(salt)#base64(iv)
class FasihDecryptor {
  static const _iterations = 11000;

  /// Returns the decrypted plaintext, or null if [content] is not in the
  /// expected encrypted format or if decryption fails.
  static String? tryDecrypt(String content) {
    try {
      final parts = content.trim().split('#');
      if (parts.length != 4) return null;

      final ciphertext = base64.decode(parts[0].trim());
      final expectedDigest = base64.decode(parts[1]);
      final saltRaw = base64.decode(parts[2]);
      final iv = base64.decode(parts[3]);

      // SHA-256 integrity check (mirrors FASIH's "datakorup" guard)
      final sha256 = SHA256Digest();
      final actualDigest = sha256.process(Uint8List.fromList(ciphertext));
      if (!_equalBytes(actualDigest, Uint8List.fromList(expectedDigest))) {
        return null;
      }

      // Replicate FASIH's salt: raw bytes → UTF-8 string → UTF-8 bytes
      // (lossy round-trip; invalid sequences become U+FFFD = EF BF BD)
      final saltBytes = Uint8List.fromList(
        utf8.encode(utf8.decode(saltRaw, allowMalformed: true)),
      );

      final derivedKey = _deriveKey(saltBytes);

      final cipher = CBCBlockCipher(AESEngine())
        ..init(
          false,
          ParametersWithIV(
            KeyParameter(derivedKey),
            Uint8List.fromList(iv),
          ),
        );

      final input = Uint8List.fromList(ciphertext);
      final plaintext = Uint8List(input.length);
      int offset = 0;
      while (offset < input.length) {
        offset += cipher.processBlock(input, offset, plaintext, offset);
      }

      return utf8.decode(_removePkcs7(plaintext)).trim();
    } catch (_) {
      return null;
    }
  }

  static Uint8List _deriveKey(Uint8List saltBytes) {
    final gen = PKCS12ParametersGenerator(SHA256Digest())
      ..init(
        _formatPkcs12Password(AppEnv.fasihSecretKey.codeUnits),
        saltBytes,
        _iterations,
      );
    return (gen.generateDerivedParameters(32)).key;
  }

  // PKCS#12 Appendix B: each code unit as 2 BE bytes, with null terminator.
  static Uint8List _formatPkcs12Password(List<int> codeUnits) {
    if (codeUnits.isEmpty) return Uint8List(0);
    final out = Uint8List((codeUnits.length + 1) * 2);
    for (int i = 0; i < codeUnits.length; i++) {
      out[i * 2] = (codeUnits[i] >> 8) & 0xFF;
      out[i * 2 + 1] = codeUnits[i] & 0xFF;
    }
    return out;
  }

  static Uint8List _removePkcs7(Uint8List data) {
    if (data.isEmpty) return data;
    final padLen = data.last;
    if (padLen < 1 || padLen > 16) return data;
    return data.sublist(0, data.length - padLen);
  }

  static bool _equalBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
