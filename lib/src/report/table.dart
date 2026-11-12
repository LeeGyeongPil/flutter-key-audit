import '../finding.dart';
import '../i18n.dart';
import '../options.dart';

/// Findings sorted from most to least serious, stable within a severity.
List<Finding> sortedFindings(List<Finding> findings) {
  final indexed = [for (var i = 0; i < findings.length; i++) (i, findings[i])];
  indexed.sort((a, b) {
    final bySeverity = b.$2.severity.rank.compareTo(a.$2.severity.rank);
    return bySeverity != 0 ? bySeverity : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Human readable report in [lang].
String renderTable(ScanResult result, Lang lang) {
  final out = StringBuffer();
  final findings = sortedFindings(result.findings);
  if (findings.isEmpty) {
    out.writeln(t(lang, 'no_findings'));
  } else {
    final rows = [
      for (final f in findings)
        [
          t(lang, 'sev_${f.severity.name}'),
          f.rule,
          f.redacted,
          f.location.text,
        ],
    ];
    final headers = [
      t(lang, 'col_severity'),
      t(lang, 'col_rule'),
      t(lang, 'col_value'),
      t(lang, 'col_location'),
    ];
    final widths = [
      for (var c = 0; c < 3; c++)
        [
          headers[c],
          ...rows.map((r) => r[c]),
        ].map(_displayWidth).reduce((a, b) => a > b ? a : b),
    ];
    String line(List<String> cells) => [
      for (var c = 0; c < 3; c++) _pad(cells[c], widths[c]),
      cells[3],
    ].join('  ');
    out.writeln(line(headers));
    for (var i = 0; i < findings.length; i++) {
      final f = findings[i];
      out.writeln(line(rows[i]));
      out.writeln('    ${t(lang, 'label_fix')}: ${t(lang, 'fix_${f.fix}')}');
      if (f.context.isNotEmpty) {
        out.writeln('    ${t(lang, 'label_context')}: ${f.context.join(', ')}');
      }
      if (f.recovered != null) {
        out.writeln('    ${t(lang, 'label_recovered')}: ${f.recovered}');
      }
      if (f.confidence != 'high') {
        out.writeln('    ${t(lang, 'label_confidence')}: ${f.confidence}');
      }
    }
  }
  final s = result.stats;
  out.writeln();
  out.writeln(
    t(lang, 'summary', {
      'files': s.filesScanned,
      'entries': s.entriesScanned,
      'billing': result.count(Severity.billing),
      'review': result.count(Severity.review),
      'info': result.count(Severity.info),
    }),
  );
  if (s.entriesSkipped > 0 || s.lowEntropySkipped > 0) {
    out.writeln(
      t(lang, 'summary_skipped', {
        'entries': s.entriesSkipped,
        'lowEntropy': s.lowEntropySkipped,
      }),
    );
  }
  if (s.linksSkipped > 0) {
    out.writeln(t(lang, 'summary_links', {'links': s.linksSkipped}));
  }
  if (result.count(Severity.billing) > 0 || result.count(Severity.review) > 0) {
    out.writeln(t(lang, 'fix_guide_hint'));
  }
  return out.toString();
}

/// Column width where Hangul counts as two cells.
int _displayWidth(String s) {
  var w = 0;
  for (final r in s.runes) {
    w += (r >= 0x1100 && r <= 0x11ff) || (r >= 0xac00 && r <= 0xd7a3) ? 2 : 1;
  }
  return w;
}

String _pad(String s, int width) =>
    s + ' ' * (width - _displayWidth(s)).clamp(0, 1000);
