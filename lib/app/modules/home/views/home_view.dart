import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/fasih_template.dart';
import '../../../data/providers/fasih_converter_sheet_api.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/fasih_backup_reader.dart';
import '../../../data/services/fasih_backup_writer.dart';
import '../../../di/injection.dart';
import '../../../router/app_router.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_side_effect.dart';
import '../cubit/home_state.dart';
import 'debug_view.dart';
import 'history_page.dart';
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
      getIt<FasihBackupWriter>(),
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
      case ShowImportSuccess(:final outputPath):
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Backup Berhasil Dibuat!'),
            content: Text('File disimpan di:\n$outputPath'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  SharePlus.instance.share(
                    ShareParams(files: [XFile(outputPath)]),
                  );
                },
                child: const Text('Bagikan'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
    }
  }

  void _showTemplatePicker(List<FasihTemplate> templates) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Survey',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: templates.length,
                  itemBuilder: (_, i) {
                    final t = templates[i];
                    return ListTile(
                      title: Text(t.title),
                      subtitle: Text('${t.fields.length} kolom · ${t.dataKey}'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _cubit.selectTemplate(t);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
              icon: const Icon(Icons.history_outlined),
              tooltip: 'Riwayat',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HistoryPage(
                    cubit: _cubit,
                    settings: getIt<SettingsRepository>(),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Debug',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider.value(
                    value: _cubit,
                    child: const DebugView(),
                  ),
                ),
              ),
            ),
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
