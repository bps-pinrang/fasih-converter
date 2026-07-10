import 'package:envied/envied.dart';

part 'app_env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class AppEnv {
  @EnviedField(varName: 'FASIH_ZIP_PASSWORD')
  static final String fasihZipPassword = _AppEnv.fasihZipPassword;

  @EnviedField(varName: 'FASIH_SECRET_KEY')
  static final String fasihSecretKey = _AppEnv.fasihSecretKey;

  @EnviedField(varName: 'FASIH_BASE_URL', obfuscate: false)
  static final String fasihBaseUrl = _AppEnv.fasihBaseUrl;

  @EnviedField(varName: 'FASIH_SSO_BASE_URL', obfuscate: false)
  static final String fasihSsoBaseUrl = _AppEnv.fasihSsoBaseUrl;

  @EnviedField(varName: 'FASIH_CLIENT_ID_INTERNAL', obfuscate: false)
  static final String fasihClientIdInternal = _AppEnv.fasihClientIdInternal;

  @EnviedField(varName: 'FASIH_CLIENT_ID_EKSTERNAL', obfuscate: false)
  static final String fasihClientIdEksternal = _AppEnv.fasihClientIdEksternal;
}
