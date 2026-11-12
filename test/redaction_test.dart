import 'package:flutter_key_audit/flutter_key_audit.dart';
import 'package:flutter_key_audit/src/fake_keys.dart';
import 'package:test/test.dart';

import 'helpers/fixtures.dart';

void main() {
  test('no output format contains a raw key, only the redacted form', () {
    final dir = tempDir();
    final fake = FakeKeys();
    final keys = <String>[for (final r in rules) fake.forRule(r.id)];
    // Half of the keys in a binary inside a zip, half in source files.
    writeBytes(
      '${dir.path}/app.apk',
      buildZip({
        'lib/arm64-v8a/libapp.so': binaryWith([
          for (final k in keys.take(5)) 'v=$k',
        ]),
      }),
    );
    writeText(
      '${dir.path}/src/.env',
      [for (final k in keys.skip(5)) 'K=$k'].join('\n'),
    );
    final envied = fake.forRule('groq');
    keys.add(envied);
    writeText('${dir.path}/src/lib/env.g.dart', buildEnviedSource('k', envied));

    final runs = [
      for (final fmt in ['table', 'json', 'sarif'])
        for (final args in [
          ['scan', '${dir.path}/app.apk', '--format', fmt],
          ['scan', '--source', '${dir.path}/src', '--format', fmt],
        ])
          cli(args),
    ];
    for (final run in runs) {
      expect(run.code, 1);
      expect(run.out, isNotEmpty);
      for (final key in keys) {
        expect(run.out.contains(key), isFalse, reason: 'raw key leaked');
        expect(run.err.contains(key), isFalse);
        // Not even the key without its first 8 characters.
        expect(run.out.contains(key.substring(8)), isFalse);
      }
    }
    // The redacted form is what shows up.
    final table = cli(['scan', '${dir.path}/app.apk']).out;
    for (final key in keys.take(5)) {
      expect(table, contains(redact(key)));
    }
    final json = cli(['scan', '${dir.path}/app.apk', '--format', 'json']).out;
    expect(json, contains('"redacted": "${redact(keys.first)}"'));
  });

  test('the report file written with --output has no raw key either', () {
    final dir = tempDir();
    final apk = buildApk('${dir.path}/a.apk');
    final out = '${dir.path}/report.sarif';
    final run = cli([
      'scan',
      apk.file.path,
      '--format',
      'sarif',
      '--output',
      out,
    ]);
    expect(run.code, 1);
    final text = readFile(out);
    for (final key in apk.keys) {
      expect(text.contains(key), isFalse);
    }
  });
}
