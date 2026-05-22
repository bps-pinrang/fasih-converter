import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';

class DebugView extends StatefulWidget {
  const DebugView({super.key});

  @override
  State<DebugView> createState() => _DebugViewState();
}

class _DebugViewState extends State<DebugView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final List<String> _stateLog = [];
  StreamSubscription<HomeState>? _sub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    final cubit = context.read<HomeCubit>();
    _stateLog.add('${_timestamp()} [init] ${_describe(cubit.state)}');
    _sub = cubit.stream.listen((state) {
      if (!mounted) return;
      setState(() => _stateLog.add('${_timestamp()} ${_describe(state)}'));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  String _timestamp() => DateTime.now().toIso8601String().substring(11, 23);

  String _describe(HomeState state) => switch (state) {
        HomeInitial() => '[HomeInitial]',
        HomeLoadingFile() => '[HomeLoadingFile]',
        HomeMultiTemplate(:final templates) =>
          '[HomeMultiTemplate] templates=${templates.length}',
        HomeFileLoaded(
          :final records,
          :final respondentMeta,
          :final isExporting,
          :final isUploading,
          :final isImporting,
        ) =>
          '[HomeFileLoaded] records=${records.length} meta=${respondentMeta.length}'
              ' exp=$isExporting up=$isUploading imp=$isImporting',
        HomeError(:final message) => '[HomeError] $message',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'State Log'),
            Tab(text: 'ZIP Tree'),
            Tab(text: 'Template'),
            Tab(text: 'Meta'),
          ],
        ),
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final loaded = state is HomeFileLoaded ? state : null;
          final cubit = context.read<HomeCubit>();
          return TabBarView(
            controller: _tabs,
            children: [
              _StateLogTab(log: List.unmodifiable(_stateLog)),
              _ZipTreeTab(dir: cubit.extractedDir),
              _TemplateTab(state: loaded),
              _MetaTab(state: loaded),
            ],
          );
        },
      ),
    );
  }
}

class _StateLogTab extends StatelessWidget {
  const _StateLogTab({required this.log});

  final List<String> log;

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) return const Center(child: Text('No state transitions.'));
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(8),
      itemCount: log.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          log[log.length - 1 - i],
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }
}

class _ZipTreeTab extends StatelessWidget {
  const _ZipTreeTab({required this.dir});

  final Directory? dir;

  @override
  Widget build(BuildContext context) {
    if (dir == null) return const Center(child: Text('No ZIP extracted.'));
    return FutureBuilder<List<String>>(
      future: _listFiles(dir!),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final files = snap.data ?? [];
        if (files.isEmpty) {
          return const Center(child: Text('Directory is empty.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: files.length,
          itemBuilder: (_, i) => Text(
            files[i],
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        );
      },
    );
  }

  Future<List<String>> _listFiles(Directory dir) async {
    final root = dir.path;
    final entries = <String>[];
    await for (final e in dir.list(recursive: true)) {
      final rel = p.relative(e.path, from: root);
      entries.add(e is Directory ? '$rel/' : rel);
    }
    entries.sort();
    return entries;
  }
}

class _TemplateTab extends StatelessWidget {
  const _TemplateTab({required this.state});

  final HomeFileLoaded? state;

  @override
  Widget build(BuildContext context) {
    if (state == null) return const Center(child: Text('No template loaded.'));
    final t = state!.template;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _kv('id', t.id),
        _kv('title', t.title),
        _kv('dataKey', t.dataKey),
        _kv('fields', '${t.fields.length}'),
        const Divider(height: 24),
        const Text(
          'Fields',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...t.fields.map((f) => _kv(f.dataKey, f.label)),
      ],
    );
  }

  Widget _kv(String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Text(
                key,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
}

class _MetaTab extends StatelessWidget {
  const _MetaTab({required this.state});

  final HomeFileLoaded? state;

  @override
  Widget build(BuildContext context) {
    if (state == null) return const Center(child: Text('No data loaded.'));
    final meta = state!.respondentMeta;
    if (meta.isEmpty) return const Center(child: Text('No respondents.'));
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: meta.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (_, i) {
        final m = meta[i];
        final preview = m.rawDataJson.length > 120
            ? '${m.rawDataJson.substring(0, 120)}…'
            : m.rawDataJson;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${i + 1}  resp: ${m.respUuid}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Text(
              'path: ${m.answersRelPath}',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              preview,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }
}
