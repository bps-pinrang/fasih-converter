import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/injection.dart';
import '../cubit/server_source_cubit.dart';
import '../cubit/server_source_state.dart';

@RoutePage()
class ServerSourceView extends StatefulWidget {
  const ServerSourceView({super.key});

  @override
  State<ServerSourceView> createState() => _ServerSourceViewState();
}

class _ServerSourceViewState extends State<ServerSourceView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ServerSourceCubit>(),
      child: BlocConsumer<ServerSourceCubit, ServerSourceState>(
        listener: (context, state) {
          if (state is ServerSourceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ambil dari Server')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Survey Period ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: state is ServerSourceLoading
                        ? null
                        : () => context
                            .read<ServerSourceCubit>()
                            .load(_controller.text.trim()),
                    child: const Text('Ambil Assignment'),
                  ),
                  const SizedBox(height: 16),
                  if (state is ServerSourceLoading)
                    Center(child: Text(state.message)),
                  if (state is ServerSourceLoaded) ...[
                    Text(
                      '${state.assignments.length} assignment'
                      ' · ${state.keyMap.length} region terenkripsi',
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: state.assignments.length,
                        itemBuilder: (_, i) {
                          final a = state.assignments[i];
                          final hasKey = state.keyMap.containsKey(a.regionId);
                          return ListTile(
                            title: Text(a.id, overflow: TextOverflow.ellipsis),
                            subtitle: Text(a.regionId),
                            trailing: hasKey
                                ? const Icon(Icons.lock_open,
                                    color: Colors.green)
                                : const Icon(Icons.lock, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () =>
                          context.router.maybePop<Map<String, String>>(
                        state.keyMap,
                      ),
                      child: const Text('Gunakan Kunci Dekripsi'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
