import 'fasih_decryptor.dart';
import 'fasih_gcm_decryptor.dart';

/// Mirrors AssignmentEncryptionHelper from the FASIH app.
///
/// Routes to AES-GCM when [wrappedDataKey] is present and non-blank,
/// falls back to legacy AES-CBC/PBE otherwise.
class FasihEncryptionHelper {
  static String? tryDecrypt(
    String cipherText, {
    String? wrappedDataKey,
  }) {
    if (wrappedDataKey != null && wrappedDataKey.trim().isNotEmpty) {
      final gcm =
          FasihGcmDecryptor.tryDecrypt(cipherText, wrappedDataKey.trim());
      if (gcm != null) return gcm;
    }
    return FasihDecryptor.tryDecrypt(cipherText);
  }
}
