import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:line_icons/line_icons.dart';

import '../../cubit/home_cubit.dart';
import '../../cubit/home_state.dart';

class HomeActionRow extends StatelessWidget {
  const HomeActionRow({super.key});

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
          ],
        );
      },
    );
  }
}
