import 'context.dart';
import 'finding.dart';
import 'options.dart';
import 'rules.dart';

/// Matches the two integer arrays envied_generator writes for an obfuscated
/// value: `_enviedkey<Field>` (random 32-bit values) and `_envieddata<Field>`
/// (the characters XORed with them). Checked against envied_generator 1.3.10
/// (https://pub.dev/packages/envied) on 2026-11-13.
final RegExp _enviedArray = RegExp(
  r'_envied(key|data)(\w+)\s*=\s*(?:<int>)?\[([\d,\s]*)\]',
);

/// Scans one text file. [displayPath] is used in locations, [fileName] only
/// to decide the source kind and Firebase file hints.
List<Finding> scanSourceText({
  required String displayPath,
  required String fileName,
  required String text,
  required ScanOptions options,
  required ScanStats stats,
}) {
  final findings = <Finding>[];
  final kind = fileName.startsWith('.env')
      ? 'source:dotenv'
      : fileName.endsWith('.dart')
      ? 'source:dart'
      : 'source:text';
  GoogleVerdict? verdict; // computed once per file, only when needed

  void add(RuleMatch m, Location loc, {String? recovered, String? extra}) {
    var severity = m.rule.severity;
    var context = <String>[kind, if (extra != null) extra];
    if (m.rule.id == 'google-api-key') {
      verdict ??= classifyGoogleKey(fileName, [text]);
      severity = verdict!.severity;
      context = [...context, ...verdict!.evidence];
    }
    findings.add(
      Finding(
        rule: m.rule.id,
        severity: severity,
        confidence: confidenceFor(m.rule, m.text),
        raw: m.text,
        location: loc,
        fix: fixFor(rule: m.rule.id, severity: severity, recovered: recovered),
        context: context,
        recovered: recovered,
      ),
    );
  }

  void lowEntropy() => stats.lowEntropySkipped++;

  // 1. Plain keys in .env files, Dart literals and any other text, per line.
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    for (final m in matchRules(
      lines[i],
      minEntropy: options.minEntropy,
      trailingBoundary: true,
      onLowEntropy: lowEntropy,
    )) {
      add(m, Location(displayPath, line: i + 1));
    }
  }

  // 2. envied: rebuild XOR-obfuscated values from the two arrays.
  final keys = <String, List<int>>{};
  final datas = <String, ({List<int> values, int line})>{};
  for (final m in _enviedArray.allMatches(text)) {
    final numbers = m
        .group(3)!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(int.parse)
        .toList();
    final field = m.group(2)!;
    if (m.group(1) == 'key') {
      keys[field] = numbers;
    } else {
      final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
      datas[field] = (values: numbers, line: line);
    }
  }
  for (final entry in datas.entries) {
    final key = keys[entry.key];
    final data = entry.value.values;
    if (key == null || key.length != data.length) continue;
    final codes = [for (var i = 0; i < data.length; i++) data[i] ^ key[i]];
    if (codes.any((c) => c < 0 || c > 0x10FFFF)) continue;
    final plain = String.fromCharCodes(codes);
    for (final m in matchRules(
      plain,
      minEntropy: options.minEntropy,
      trailingBoundary: true,
      onLowEntropy: lowEntropy,
    )) {
      add(
        m,
        Location(displayPath, line: entry.value.line),
        recovered: 'envied',
        extra: 'envied_field:${entry.key}',
      );
    }
  }
  return findings;
}
