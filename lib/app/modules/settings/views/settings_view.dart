import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../di/injection.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_side_effect.dart';
import '../cubit/settings_state.dart';

@RoutePage()
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final SettingsCubit _cubit;
  StreamSubscription<SettingsSideEffect>? _sub;
  final _sheetIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cubit = SettingsCubit(getIt<SettingsRepository>());
    final initial = _cubit.state as SettingsInitial;
    _sheetIdController.text = initial.sheetId;
    _sub = _cubit.sideEffects.listen(_handleSideEffect);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cubit.close();
    _sheetIdController.dispose();
    super.dispose();
  }

  void _handleSideEffect(SettingsSideEffect effect) {
    switch (effect) {
      case ShowSettingsSnackbar(:final title, :final message, :final isError):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $message'),
            backgroundColor: isError ? Colors.red.shade400 : null,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: BlocConsumer<SettingsCubit, SettingsState>(
          listener: (context, state) {
            if (state is SettingsSaved) {
              context.router.pop();
            }
          },
          builder: (context, state) {
            final isSaving = state is SettingsSaving;
            final hasCredentials =
                state is SettingsInitial ? state.hasCredentials : false;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kredensial Google Service Account',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : _cubit.pickCredentialsFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      hasCredentials ? 'Ganti File JSON' : 'Pilih File JSON',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Google Sheet ID / URL',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sheetIdController,
                    decoration: const InputDecoration(
                      hintText: 'Sheet ID atau URL Google Sheets',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isSaving,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () => _cubit.save(_sheetIdController.text),
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: isSaving ? null : _cubit.clearCredentials,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Hapus Semua Kredensial'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
