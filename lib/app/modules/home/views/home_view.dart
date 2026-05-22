import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:line_icons/line_icons.dart';

import '../../../data/models/fasih_template.dart';
import '../../../data/providers/fasih_converter_sheet_api.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/fasih_backup_reader.dart';
import '../../../di/injection.dart';
import '../../../router/app_router.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_side_effect.dart';
import '../cubit/home_state.dart';

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
                  _cubit.selectTemplate(t);
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
                builder: (context, state) => Text(
                  'Fasih Converter ${_cubit.appVersion}',
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
              _buildDropZone(),
              const SizedBox(height: 16),
              _buildActionRow(),
              const SizedBox(height: 16),
              _buildDataTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    return DottedBorder(
      color: Colors.blueAccent,
      borderType: BorderType.RRect,
      dashPattern: const [8, 4],
      radius: const Radius.circular(12),
      child: Material(
        elevation: 0,
        color: const Color(0xFFDEDEDE).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _cubit.pickAndLoadBackup,
          child: SizedBox(
            width: double.infinity,
            height: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: BlocBuilder<HomeCubit, HomeState>(
                builder: (_, state) => _buildDropZoneContent(state),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropZoneContent(HomeState state) {
    if (state is HomeLoadingFile) {
      return const Center(
        child: SpinKitFadingCircle(color: Colors.blue, size: 30),
      );
    }

    if (state is HomeFileLoaded) {
      return Row(
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: Icon(Icons.file_present, color: Colors.blueAccent),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.file.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('Ukuran: ${filesize(state.file.size)}'),
                Text(
                  '${state.template.title} · ${state.records.length} responden',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.upload_file, color: Colors.blueAccent),
        SizedBox(height: 8),
        Text(
          'Upload File Backup Fasih (.zip)',
          style: TextStyle(color: Colors.blueAccent, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (_, state) {
        final loaded = state is HomeFileLoaded ? state : null;
        final hasData = loaded != null;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasData ? _cubit.shareExcel : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Bagikan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: hasData ? _cubit.clearData : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.red.shade300,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                    child: const Text('Hapus'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasData && !loaded.isExporting
                        ? _cubit.exportToExcel
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.green.shade400,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                    icon: loaded?.isExporting == true
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LineIcons.excelFile, size: 18),
                    label: const Text('Ekspor Excel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasData && !loaded.isUploading
                        ? _cubit.uploadToSheets
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.teal.shade400,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                    icon: loaded?.isUploading == true
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.table_chart_outlined, size: 18),
                    label: const Text('Upload Sheets'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataTable() {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (_, state) {
        if (state is! HomeFileLoaded) return const SizedBox.shrink();

        final template = state.template;
        final records = state.records;

        final columns = template.fields
            .map((f) => DataColumn2(label: Text(f.label), fixedWidth: 150))
            .toList();

        return Container(
          height: MediaQuery.sizeOf(context).height * 0.5,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.2),
                spreadRadius: 4,
                offset: const Offset(0, 8),
                blurRadius: 10,
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: DataTable2(
            columnSpacing: 12,
            minWidth: template.fields.length * 150.0,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade100),
            border: TableBorder.all(color: Colors.grey.shade300),
            empty: records.isEmpty
                ? const Center(child: Text('Belum ada data'))
                : null,
            columns: columns,
            rows: records
                .take(200)
                .map(
                  (record) => DataRow2(
                    cells: template.fields
                        .map(
                          (f) => DataCell(
                            Text(
                              record[f.dataKey],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
