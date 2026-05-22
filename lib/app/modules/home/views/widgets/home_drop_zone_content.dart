import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../cubit/home_cubit.dart';
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
      final cubit = context.read<HomeCubit>();
      final canSwitch = cubit.availableTemplates.length > 1;
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
                  loaded.template.title,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      '${loaded.records.length} responden',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (canSwitch) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: cubit.changeTemplate,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Ganti'),
                      ),
                    ],
                  ],
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
