import '../models/fasih_record.dart';
import '../models/fasih_template.dart';

class FasihTableHtmlGenerator {
  static String generate(
    FasihTemplate template,
    List<FasihRecord> records,
  ) {
    final fields = template.fields;
    final buffer = StringBuffer();

    buffer.writeln('<table id="_table">');
    buffer.writeln('<thead><tr>');
    buffer.writeln('<th>#</th>');
    for (final f in fields) {
      final label = _esc(f.label);
      buffer.writeln('<th>$label</th>');
    }
    buffer.writeln('</tr></thead>');

    buffer.writeln('<tbody>');
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      buffer.writeln('<tr>');
      buffer.writeln('<td class="num">${i + 1}</td>');
      for (final f in fields) {
        final value = _esc(record[f.dataKey]);
        buffer.writeln('<td>$value</td>');
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</tbody>');
    buffer.writeln('</table>');

    return buffer.toString();
  }

  static String wrapWithStyling(String tableHtml, int recordCount) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         font-size: 12px; background: #fff; }
  .wrapper { overflow-x: auto; width: 100%; }
  table { border-collapse: collapse; white-space: nowrap; min-width: 100%; }
  thead tr { background: #0077EF; color: #fff; position: sticky; top: 0; z-index: 1; }
  th { padding: 8px 10px; text-align: left; font-weight: 600;
       border-right: 1px solid rgba(255,255,255,0.2); }
  td { padding: 6px 10px; border-bottom: 1px solid #e5e7eb;
       border-right: 1px solid #e5e7eb; color: #374151; }
  td.num { color: #9ca3af; text-align: right; user-select: none; }
  tr:nth-child(even) { background: #f9fafb; }
  tr:hover { background: #eff6ff; }
</style>
</head>
<body>
<div class="wrapper" id="_flutter_target_do_not_delete">
$tableHtml
</div>
<script>
  function reportHeight() {
    var h = document.getElementById("_flutter_target_do_not_delete").scrollHeight;
    console.log(h);
  }
  new ResizeObserver(reportHeight).observe(
    document.getElementById("_flutter_target_do_not_delete")
  );
  reportHeight();
</script>
</body>
</html>''';
  }

  static String _esc(String s) {
    if (s.isEmpty) return '';
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
