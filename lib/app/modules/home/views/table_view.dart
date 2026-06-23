import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../data/models/fasih_record.dart';
import '../../../data/models/fasih_template.dart';
import '../../../data/services/app_error_logger.dart';
import '../../../data/services/fasih_table_html_generator.dart';

class _TableHtmlArgs {
  final List<FasihTemplateField> fields;
  final List<FasihRecord> records;
  const _TableHtmlArgs(this.fields, this.records);
}

String _buildTableHtml(_TableHtmlArgs args) {
  return FasihTableHtmlGenerator.generateFullPage(args.fields, args.records);
}

class TableView extends StatefulWidget {
  final FasihTemplate template;
  final List<FasihRecord> records;

  const TableView({
    super.key,
    required this.template,
    required this.records,
  });

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  String? _html;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateHtml();
  }

  Future<void> _generateHtml() async {
    try {
      final html = await compute(
        _buildTableHtml,
        _TableHtmlArgs(widget.template.fields, widget.records),
      );
      if (!mounted) return;
      setState(() => _html = html);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tabel siap.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      AppErrorLogger.instance.log(
        e,
        st,
        context: {
          'operasi': 'generateTableHtml',
          'nama_template': widget.template.title,
          'id_template': widget.template.id,
          'jumlah_responden': '${widget.records.length}',
          'jumlah_kolom': '${widget.template.fields.length}',
        },
      );
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membangun tabel: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.template.title,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.records.length} responden'
              ' · ${widget.template.fields.length} kolom',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _generateHtml();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : _html == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Membangun tabel'
                        ' (${widget.records.length} baris'
                        ' × ${widget.template.fields.length} kolom)…',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : InAppWebView(
                  initialData: InAppWebViewInitialData(data: _html!),
                  initialSettings: InAppWebViewSettings(
                    supportZoom: false,
                    isInspectable: false,
                    useWideViewPort: true,
                    horizontalScrollBarEnabled: true,
                    verticalScrollBarEnabled: true,
                  ),
                ),
    );
  }
}
