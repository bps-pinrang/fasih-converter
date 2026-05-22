import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../cubit/home_state.dart';

class HomeDropZoneContent extends StatelessWidget {
  const HomeDropZoneContent({super.key, required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    if (state is HomeLoadingFile) {
      return const Center(
        child: SpinKitFadingCircle(color: Colors.blue, size: 30),
      );
    }

    if (state is HomeFileLoaded) {
      final loaded = state as HomeFileLoaded;
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
                  loaded.file.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('Ukuran: ${filesize(loaded.file.size)}'),
                Text(
                  '${loaded.template.title} · ${loaded.records.length} responden',
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
}
