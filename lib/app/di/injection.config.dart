// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:json_converter/app/data/providers/fasih_converter_sheet_api.dart'
    as _i183;
import 'package:json_converter/app/data/repositories/settings_repository.dart'
    as _i55;
import 'package:json_converter/app/data/services/fasih_backup_reader.dart'
    as _i123;
import 'package:json_converter/app/di/app_module.dart' as _i983;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final appModule = _$AppModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => appModule.prefs,
      preResolve: true,
    );
    gh.singleton<_i123.FasihBackupReader>(() => _i123.FasihBackupReader());
    gh.singleton<_i55.SettingsRepository>(
        () => _i55.SettingsRepository(gh<_i460.SharedPreferences>()));
    gh.singleton<_i183.FasihConverterSheetApi>(
        () => _i183.FasihConverterSheetApi(gh<_i55.SettingsRepository>()));
    return this;
  }
}

class _$AppModule extends _i983.AppModule {}
