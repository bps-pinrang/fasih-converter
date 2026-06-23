import 'dart:convert';

import '../models/fasih_record.dart';
import '../models/fasih_template.dart';

class FasihTableHtmlGenerator {
  /// Generates a full-page HTML document with lazy row rendering.
  ///
  /// Data is embedded as a compact JSON array and rows are appended to the
  /// DOM 100 at a time via IntersectionObserver, so the initial render is fast
  /// regardless of dataset size (avoids creating 200K+ DOM nodes upfront).
  static String generateFullPage(
    List<FasihTemplateField> fields,
    List<FasihRecord> records,
  ) {
    final thead = StringBuffer('<tr><th>#</th>');
    for (final f in fields) {
      thead.write('<th>${_esc(f.label)}</th>');
    }
    thead.write('</tr>');

    // Build compact JSON — all values are already strings, no HTML escaping
    // needed for cell values because JS uses textContent (not innerHTML).
    // Escape "</" to prevent "</script>" from breaking the HTML parser.
    final rows =
        records.map((r) => fields.map((f) => r[f.dataKey]).toList()).toList();
    final dataJson = jsonEncode(rows).replaceAll('</', r'<\/');

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         font-size: 12px; background: #fff; }
  table { border-collapse: separate; border-spacing: 0; white-space: nowrap; }
  thead { position: relative; z-index: 1; will-change: transform; }
  th { padding: 8px 10px; text-align: left; font-weight: 600;
       background: #0077EF; color: #fff;
       border-right: 1px solid rgba(255,255,255,0.2);
       border-bottom: 2px solid rgba(255,255,255,0.3); }
  td { padding: 6px 10px; border-bottom: 1px solid #e5e7eb;
       border-right: 1px solid #e5e7eb; color: #374151; }
  td.num { color: #9ca3af; text-align: right; user-select: none; }
  tbody tr:nth-child(even) { background: #f9fafb; }
  tbody tr:hover { background: #eff6ff; }
  #load-status { text-align: center; padding: 12px; color: #6b7280; font-size: 11px; }
</style>
</head>
<body>
<table>
  <thead id="thead">${thead.toString()}</thead>
  <tbody id="tbody"></tbody>
</table>
<div id="load-status"></div>
<div id="sentinel"></div>
<script>
var DATA = $dataJson;
var PAGE = 100;
var loaded = 0;
function loadRows() {
  if (loaded >= DATA.length) {
    document.getElementById('load-status').textContent =
      'Menampilkan semua ' + DATA.length + ' baris';
    document.getElementById('sentinel').style.display = 'none';
    return;
  }
  var tbody = document.getElementById('tbody');
  var end = Math.min(loaded + PAGE, DATA.length);
  var frag = document.createDocumentFragment();
  for (var i = loaded; i < end; i++) {
    var tr = document.createElement('tr');
    var numTd = document.createElement('td');
    numTd.className = 'num';
    numTd.textContent = String(i + 1);
    tr.appendChild(numTd);
    for (var j = 0; j < DATA[i].length; j++) {
      var td = document.createElement('td');
      td.textContent = DATA[i][j];
      tr.appendChild(td);
    }
    frag.appendChild(tr);
  }
  tbody.appendChild(frag);
  loaded = end;
  document.getElementById('load-status').textContent =
    'Menampilkan ' + loaded + ' dari ' + DATA.length + ' baris';
}
loadRows();
var obs = new IntersectionObserver(function(entries) {
  if (entries[0].isIntersecting && loaded < DATA.length) loadRows();
}, { rootMargin: '200px' });
obs.observe(document.getElementById('sentinel'));
// Pin header: translateY offsets the scroll so thead stays at viewport top.
// More reliable than position:sticky inside a WebView's native scroll container.
var theadEl = document.getElementById('thead');
window.addEventListener('scroll', function() {
  theadEl.style.transform = 'translateY(' + window.scrollY + 'px)';
}, { passive: true });
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
