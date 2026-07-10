import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Decrypts data.json files encrypted by FASIH's CryptoGCM (v2.16+).
///
/// Wire format: Base64( IV[12] || AES-GCM-ciphertext+tag[16] )
/// Key: Base64 decode of wrappedDataKey (16, 24, or 32 bytes).
class FasihGcmDecryptor {
  static const _validKeyLengths = {16, 24, 32};

  /// Returns decrypted plaintext, or null if the key/payload is invalid or
  /// the GCM authentication tag fails.
  static String? tryDecrypt(String encryptedB64, String wrappedDataKeyB64) {
    try {
      final key = base64.decode(wrappedDataKeyB64);
      if (!_validKeyLengths.contains(key.length)) return null;

      final data = base64.decode(encryptedB64);
      if (data.length < 12 + 16) return null; // min: IV + GCM tag

      final iv = data.sublist(0, 12);
      final ct = data.sublist(12); // ciphertext + 16-byte GCM tag

      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

      final plain = cipher.process(Uint8List.fromList(ct));
      return utf8.decode(plain);
    } on InvalidCipherTextException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
