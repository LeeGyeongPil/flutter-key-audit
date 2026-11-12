import 'dart:convert';

import '../finding.dart';
import '../i18n.dart';
import '../options.dart';
import '../rules.dart';
import 'json.dart';
import 'table.dart';

/// SARIF 2.1.0 report for code scanning uploads. Always English (a machine
/// format), and never contains the raw key.
String renderSarif(ScanResult result) {
  final findings = sortedFindings(result.findings);
  final ruleIds = [for (final r in rules) r.id];
  String level(Severity s) => switch (s) {
    Severity.billing => 'error',
    Severity.review => 'warning',
    Severity.info => 'note',
  };
  final sarif = {
    r'$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
    'version': '2.1.0',
    'runs': [
      {
        'tool': {
          'driver': {
            'name': 'flutter-key-audit',
            'version': toolVersion,
            'informationUri':
                'https://github.com/LeeGyeongPil/flutter-key-audit',
            'rules': [
              for (final r in rules)
                {
                  'id': r.id,
                  'shortDescription': {'text': t(Lang.en, 'rule_${r.id}')},
                  'defaultConfiguration': {'level': level(r.severity)},
                },
            ],
          },
        },
        'results': [
          for (final f in findings)
            {
              'ruleId': f.rule,
              'ruleIndex': ruleIds.indexOf(f.rule),
              'level': level(f.severity),
              'message': {
                'text':
                    '${t(Lang.en, 'rule_${f.rule}')}: ${f.redacted}. '
                    '${t(Lang.en, 'fix_${f.fix}')}',
              },
              'locations': [
                {
                  'physicalLocation': {
                    'artifactLocation': {'uri': f.location.path},
                    'region': {
                      if (f.location.line != null) 'startLine': f.location.line,
                      if (f.location.offset != null) ...{
                        'byteOffset': f.location.offset,
                        'byteLength': f.raw.length,
                      },
                    },
                  },
                },
              ],
            },
        ],
      },
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(sarif)}\n';
}
