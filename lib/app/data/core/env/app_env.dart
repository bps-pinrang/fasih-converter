import 'package:envied/envied.dart';

part 'app_env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class AppEnv {
  @EnviedField(varName: 'FASIH_ZIP_PASSWORD')
  static final String fasihZipPassword = _AppEnv.fasihZipPassword;
}
