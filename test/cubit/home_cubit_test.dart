import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/models/fasih_template.dart';
import 'package:json_converter/app/data/providers/fasih_converter_sheet_api.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';
import 'package:json_converter/app/data/services/fasih_backup_reader.dart';
import 'package:json_converter/app/data/services/fasih_backup_writer.dart';
import 'package:json_converter/app/modules/home/cubit/home_cubit.dart';
import 'package:json_converter/app/modules/home/cubit/home_state.dart';
import 'package:mocktail/mocktail.dart';

class MockFasihBackupReader extends Mock implements FasihBackupReader {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockFasihConverterSheetApi extends Mock
    implements FasihConverterSheetApi {}

class MockFasihBackupWriter extends Mock implements FasihBackupWriter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub package_info_plus platform channel so _init() doesn't throw.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {
        'appName': 'test',
        'packageName': 'com.test',
        'version': '1.0.0',
        'buildNumber': '1',
        'buildSignature': '',
        'installerStore': null,
      },
    );
  });

  late MockFasihBackupReader reader;
  late MockSettingsRepository settings;
  late MockFasihConverterSheetApi sheetApi;
  late MockFasihBackupWriter writer;

  setUp(() {
    reader = MockFasihBackupReader();
    settings = MockSettingsRepository();
    sheetApi = MockFasihConverterSheetApi();
    writer = MockFasihBackupWriter();

    when(() => settings.lastExtractedDirPath).thenReturn(null);
    when(() => settings.lastTemplateId).thenReturn(null);
    when(() => settings.clearLastSession()).thenAnswer((_) async {});
  });

  HomeCubit buildCubit() => HomeCubit(reader, settings, sheetApi, writer);

  test('initial state is HomeInitial', () {
    expect(buildCubit().state, isA<HomeInitial>());
  });

  group('clearData', () {
    blocTest<HomeCubit, HomeState>(
      'emits HomeInitial',
      build: buildCubit,
      act: (c) => c.clearData(),
      expect: () => [isA<HomeInitial>()],
    );
  });

  group('selectTemplate', () {
    blocTest<HomeCubit, HomeState>(
      'does nothing if state is not HomeMultiTemplate',
      build: buildCubit,
      act: (c) => c.selectTemplate(_template()),
      expect: () => [],
    );
  });
}

FasihTemplate _template() => FasihTemplate.fromJson(
      'test-uuid',
      '{"title":"T","dataKey":"t","components":[[{"type":25,"dataKey":"r1","label":"Q1"}]]}',
    );
