import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';

import '../../../data/models/backup_history_entry.dart';
import '../../../data/repositories/settings_repository.dart';
import '../cubit/home_cubit.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.cubit,
    required this.settings,
  });

  final HomeCubit cubit;
  final SettingsRepository settings;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<BackupHistoryEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.settings.loadHistory();
  }

  Future<void> _remove(BackupHistoryEntry entry) async {
    await widget.settings.removeFromHistory(entry.dirPath);
    if (!mounted) return;
    setState(() => _entries = widget.settings.loadHistory());
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Backup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade100,
      body: _entries.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada riwayat.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = _entries[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.folder_zip_outlined,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      entry.zipName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.templateTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${filesize(entry.zipSize)} · ${_formatDate(entry.loadedAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Hapus',
                      onPressed: () => _remove(entry),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.cubit.loadFromHistory(entry);
                    },
                  ),
                );
              },
            ),
    );
  }
}
