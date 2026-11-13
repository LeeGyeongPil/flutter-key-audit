import 'dart:convert';

import '../finding.dart';
import '../options.dart';
import 'table.dart';

/// Tool version, kept in sync with pubspec.yaml (a test checks this).
const toolVersion = '0.1.1';

/// JSON report. Keys and values are English and identical in every language.
/// The raw key never appears: only [Finding.redacted].
String renderJson(ScanResult result) {
  final findings = sortedFindings(result.findings);
  final map = {
    'schema': 1,
    'tool': {'name': 'flutter-key-audit', 'version': toolVersion},
    'findings': [
      for (final f in findings)
        {
          'rule': f.rule,
          'severity': f.severity.name,
          'confidence': f.confidence,
          'redacted': f.redacted,
          'location': {
            'path': f.location.path,
            'offset': f.location.offset,
            'line': f.location.line,
          },
          'context': f.context,
          'fix': f.fix,
          'recovered': f.recovered,
        },
    ],
    'summary': {
      'billing': result.count(Severity.billing),
      'review': result.count(Severity.review),
      'info': result.count(Severity.info),
      'files_scanned': result.stats.filesScanned,
      'entries_scanned': result.stats.entriesScanned,
      'entries_skipped': result.stats.entriesSkipped,
      'low_entropy_skipped': result.stats.lowEntropySkipped,
      'links_skipped': result.stats.linksSkipped,
    },
  };
  return '${const JsonEncoder.withIndent('  ').convert(map)}\n';
}
