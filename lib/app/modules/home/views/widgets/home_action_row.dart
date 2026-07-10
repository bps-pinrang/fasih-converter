import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:line_icons/line_icons.dart';

import '../../../../data/repositories/fasih_auth_repository.dart';
import '../../../../di/injection.dart';
import '../../../../router/app_router.dart';
import '../../cubit/home_cubit.dart';
import '../../cubit/home_state.dart';
import '../table_view.dart';

class HomeActionRow extends StatelessWidget {
  const HomeActionRow({super.key});

  static Future<void> _ambilDariServer(
    BuildContext context,
    HomeCubit cubit,
  ) async {
    final auth = getIt<FasihAuthRepository>();
    if (!auth.isLoggedIn) {
      final loggedIn = await context.pushRoute<bool>(const LoginRoute());
      if (loggedIn != true || !context.mounted) return;
    }
    if (!context.mounted) return;
    final keyMap = await context.pushRoute<Map<String, String>>(
      const ServerSourceRoute(),
    );
    if (keyMap == null || keyMap.isEmpty || !context.mounted) return;
    await cubit.reloadWithKeyMap(keyMap);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final loaded = state is HomeFileLoaded ? state : null;
        final hasData = loaded != null;
        final cubit = context.read<HomeCubit>();
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasData ? cubit.shareExcel : null,
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
                    onPressed: hasData ? cubit.clearData : null,
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
                        ? cubit.exportToExcel
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
                        ? cubit.uploadToSheets
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasData && !loaded.isImporting
                        ? cubit.importFromExcel
                        : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.orange.shade400,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                    icon: (loaded?.isImporting ?? false)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Import Excel → Backup'),
                  ),
                ),
              ],
            ),
            if (hasData) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TableView(
                        template: loaded.template,
                        records: loaded.records,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade400,
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                  icon: const Icon(Icons.table_rows_outlined, size: 18),
                  label: Text(
                    'Lihat Tabel (${loaded.records.length} baris)',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _ambilDariServer(context, cubit),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade400,
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Ambil Kunci dari Server'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
