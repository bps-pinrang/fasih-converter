import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_converter/app/data/repositories/settings_repository.dart';
import 'package:json_converter/app/modules/settings/cubit/settings_cubit.dart';
import 'package:json_converter/app/modules/settings/cubit/settings_state.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository settings;

  setUp(() {
    settings = MockSettingsRepository();
    when(() => settings.sheetId).thenReturn(null);
    when(() => settings.credentialsJson).thenReturn(null);
  });

  SettingsCubit buildCubit() => SettingsCubit(settings);

  test('initial state reflects repository values', () {
    when(() => settings.sheetId).thenReturn('sheet-id-123');
    when(() => settings.credentialsJson).thenReturn('{}');
    final cubit = buildCubit();
    final state = cubit.state as SettingsInitial;
    expect(state.sheetId, 'sheet-id-123');
    expect(state.hasCredentials, true);
  });

  group('save', () {
    blocTest<SettingsCubit, SettingsState>(
      'emits SettingsSaving then SettingsSaved on success',
      build: buildCubit,
      setUp: () {
        when(() => settings.saveSheetId(any())).thenAnswer((_) async {});
      },
      act: (c) => c.save('sheet-abc'),
      expect: () => [isA<SettingsSaving>(), isA<SettingsSaved>()],
    );

    blocTest<SettingsCubit, SettingsState>(
      'does not emit when sheetId is empty',
      build: buildCubit,
      act: (c) => c.save(''),
      expect: () => [],
    );
  });

  group('clearCredentials', () {
    blocTest<SettingsCubit, SettingsState>(
      'emits SettingsInitial after clearing',
      build: buildCubit,
      setUp: () {
        when(() => settings.clearAll()).thenAnswer((_) async {});
      },
      act: (c) => c.clearCredentials(),
      expect: () => [isA<SettingsInitial>()],
    );
  });
}
