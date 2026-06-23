import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../data/services/app_error_logger.dart';
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
    _tabs = TabController(length: 5, vsync: this);
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'State Log'),
            Tab(text: 'ZIP Tree'),
            Tab(text: 'Template'),
            Tab(text: 'Meta'),
            Tab(text: 'Errors'),
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
              _ErrorsTab(appVersion: cubit.appVersion),
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
          itemBuilder: (_, i) {
            final path = files[i];
            final isDir = path.endsWith('/');
            final parts = path.split('/').where((s) => s.isNotEmpty).toList();
            final depth = parts.length - 1;
            final name = parts.isEmpty ? path : parts.last;
            return Padding(
              padding: EdgeInsets.only(top: 2, left: 8.0 + depth * 16.0),
              child: Row(
                children: [
                  Icon(
                    isDir ? Icons.folder : Icons.insert_drive_file_outlined,
                    size: 14,
                    color: isDir ? Colors.amber.shade700 : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isDir ? '$name/' : name,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: isDir ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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

class _ErrorsTab extends StatefulWidget {
  const _ErrorsTab({required this.appVersion});

  final String appVersion;

  @override
  State<_ErrorsTab> createState() => _ErrorsTabState();
}

class _ErrorsTabState extends State<_ErrorsTab> {
  @override
  void initState() {
    super.initState();
    AppErrorLogger.instance.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppErrorLogger.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = AppErrorLogger.instance.reports.reversed.toList();
    if (reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text('Tidak ada error.'),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                '${reports.length} error',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: AppErrorLogger.instance.clear,
                child: const Text('Hapus Semua'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => _shareAll(reports),
                icon: const Icon(Icons.share, size: 14),
                label: const Text('Bagikan'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (_, i) => _ErrorCard(
              report: reports[i],
              onShare: () => _shareOne(reports[i]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareOne(ErrorReport r) async {
    await SharePlus.instance.share(
      ShareParams(
        text: AppErrorLogger.formatReport(r, appVersion: widget.appVersion),
      ),
    );
  }

  Future<void> _shareAll(List<ErrorReport> reports) async {
    final buf = StringBuffer();
    for (var i = 0; i < reports.length; i++) {
      if (i > 0) buf.writeln('\n${'=' * 50}\n');
      buf.write(
        AppErrorLogger.formatReport(reports[i], appVersion: widget.appVersion),
      );
    }
    await SharePlus.instance.share(ShareParams(text: buf.toString()));
  }
}

class _ErrorCard extends StatefulWidget {
  const _ErrorCard({required this.report, required this.onShare});

  final ErrorReport report;
  final VoidCallback onShare;

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final errorPreview =
        r.error.length > 200 ? '${r.error.substring(0, 200)}…' : r.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                r.timestamp.toIso8601String().substring(0, 23),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              tooltip: 'Lihat stack trace',
            ),
            IconButton(
              icon: const Icon(Icons.share, size: 16),
              onPressed: widget.onShare,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              tooltip: 'Bagikan error ini',
            ),
          ],
        ),
        if (r.context.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: r.context.entries
                .map(
                  (e) => Chip(
                    label: Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          errorPreview,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Colors.red,
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              r.stackTrace.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
