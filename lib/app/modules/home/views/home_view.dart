import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/fasih_template.dart';
import '../../../data/providers/fasih_converter_sheet_api.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/fasih_backup_reader.dart';
import '../../../di/injection.dart';
import '../../../router/app_router.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_side_effect.dart';
import '../cubit/home_state.dart';
import 'widgets/home_action_row.dart';
import 'widgets/home_data_table.dart';
import 'widgets/home_drop_zone.dart';

@RoutePage()
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeCubit _cubit;
  StreamSubscription<HomeSideEffect>? _sub;

  @override
  void initState() {
    super.initState();
    _cubit = HomeCubit(
      getIt<FasihBackupReader>(),
      getIt<SettingsRepository>(),
      getIt<FasihConverterSheetApi>(),
    );
    _sub = _cubit.sideEffects.listen(_handleSideEffect);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cubit.close();
    super.dispose();
  }

  void _handleSideEffect(HomeSideEffect effect) {
    switch (effect) {
      case ShowSnackbar(:final title, :final message, :final isError):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $message'),
            backgroundColor: isError ? Colors.red.shade400 : null,
          ),
        );
      case ShowSuccessDialog(:final title, :final message):
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      case ShowTemplatePicker(:final templates):
        _showTemplatePicker(templates);
    }
  }

  void _showTemplatePicker(List<FasihTemplate> templates) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Survey',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...templates.map(
              (t) => ListTile(
                title: Text(t.title),
                subtitle: Text('${t.fields.length} kolom · ${t.dataKey}'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.read<HomeCubit>().selectTemplate(t);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.pushRoute(const SettingsRoute()),
              tooltip: 'Pengaturan',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BlocBuilder<HomeCubit, HomeState>(
                builder: (context, _) => Text(
                  'Fasih Converter ${context.read<HomeCubit>().appVersion}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '© 2022 IPDS BPS Kabupaten Pinrang',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              ),
              const SizedBox(height: 24),
              const HomeDropZone(),
              const SizedBox(height: 16),
              const HomeActionRow(),
              const SizedBox(height: 16),
              const HomeDataTable(),
            ],
          ),
        ),
      ),
    );
  }
}
