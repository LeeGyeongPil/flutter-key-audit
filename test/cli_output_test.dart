import 'dart:convert';
import 'dart:io';

import 'package:flutter_key_audit/src/fake_keys.dart';
import 'package:flutter_key_audit/src/report/json.dart';
import 'package:test/test.dart';

import 'helpers/fixtures.dart';

void main() {
  final fake = FakeKeys();

  /// A folder with one file for each severity and a clean one.
  Map<String, String> fixtures() {
    final dir = tempDir();
    writeText('${dir.path}/billing/a.txt', 'k=${fake.forRule('groq')}\n');
    writeText(
      '${dir.path}/review/a.txt',
      'k=${fake.forRule('google-api-key')}\n',
    );
    writeText(
      '${dir.path}/info/google-services.json',
      '{"k":"${fake.forRule('google-api-key')}"}\n',
    );
    writeText('${dir.path}/clean/a.txt', 'nothing to see here\n');
    return {
      for (final n in ['billing', 'review', 'info', 'clean'])
        n: '${dir.path}/$n',
    };
  }

  group('JSON', () {
    test('has schema, findings fields and summary', () {
      final dir = tempDir();
      final apk = buildApk('${dir.path}/a.apk');
      final run = cli(['scan', apk.file.path, '--format', 'json']);
      expect(run.code, 1);
      final doc = jsonDecode(run.out) as Map<String, dynamic>;
      expect(doc['schema'], 1);
      expect((doc['tool'] as Map)['version'], toolVersion);
      final findings = doc['findings'] as List;
      expect(findings, hasLength(3));
      for (final f in findings.cast<Map<String, dynamic>>()) {
        expect(
          f.keys,
          containsAll([
            'rule',
            'severity',
            'confidence',
            'redacted',
            'location',
            'context',
            'fix',
            'recovered',
          ]),
        );
        expect(f['severity'], 'billing');
        final loc = f['location'] as Map;
        expect(loc['path'], contains('a.apk!/'));
        expect(loc['offset'], isA<int>());
        expect(f['fix'], 'rotate_and_proxy');
      }
      final summary = doc['summary'] as Map;
      expect(summary['billing'], 3);
      expect(summary['entries_scanned'], 3);
      expect(
        summary.keys,
        containsAll([
          'review',
          'info',
          'files_scanned',
          'entries_skipped',
          'low_entropy_skipped',
        ]),
      );
    });

    test('version constant matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        RegExp(r'^version: (\S+)', multiLine: true).firstMatch(pubspec)![1],
        toolVersion,
      );
    });
  });

  group('SARIF', () {
    test('2.1.0 structure with rules and located results', () {
      final dir = tempDir();
      final apk = buildApk('${dir.path}/a.apk');
      final run = cli(['scan', apk.file.path, '--format', 'sarif']);
      final doc = jsonDecode(run.out) as Map<String, dynamic>;
      expect(doc['version'], '2.1.0');
      final runs = doc['runs'] as List;
      final driver = ((runs[0] as Map)['tool'] as Map)['driver'] as Map;
      expect(driver['name'], 'flutter-key-audit');
      expect(driver['rules'], hasLength(9));
      final results = (runs[0] as Map)['results'] as List;
      expect(results, hasLength(3));
      for (final r in results.cast<Map<String, dynamic>>()) {
        expect(r['level'], 'error');
        expect(r['ruleId'], isNotEmpty);
        final loc =
            ((r['locations'] as List).first as Map)['physicalLocation'] as Map;
        expect((loc['artifactLocation'] as Map)['uri'], contains('a.apk!/'));
        expect((loc['region'] as Map)['byteOffset'], isA<int>());
      }
    });

    test('source findings use startLine and info maps to note', () {
      final f = fixtures();
      final src = cli(['scan', '--source', f['billing']!, '--format', 'sarif']);
      final r0 =
          (((jsonDecode(src.out) as Map)['runs'] as List).first
                  as Map)['results']
              as List;
      final region =
          (((r0.first as Map)['locations'] as List).first
                  as Map)['physicalLocation']['region']
              as Map;
      expect(region['startLine'], 1);
      final info = cli([
        'scan',
        f['info']!,
        '--format',
        'sarif',
        '--fail-on',
        'none',
      ]);
      final r1 =
          (((jsonDecode(info.out) as Map)['runs'] as List).first
                  as Map)['results']
              as List;
      expect((r1.first as Map)['level'], 'note');
    });
  });

  group('exit codes', () {
    test('--fail-on matrix', () {
      final f = fixtures();
      // dir -> fail-on -> expected exit code
      const expected = {
        'billing': {'billing': 1, 'review': 1, 'info': 1, 'none': 0},
        'review': {'billing': 0, 'review': 1, 'info': 1, 'none': 0},
        'info': {'billing': 0, 'review': 0, 'info': 1, 'none': 0},
        'clean': {'billing': 0, 'review': 0, 'info': 0, 'none': 0},
      };
      expected.forEach((name, perLevel) {
        perLevel.forEach((level, code) {
          final run = cli(['scan', f[name]!, '--fail-on', level]);
          expect(run.code, code, reason: '$name --fail-on $level');
        });
      });
    });

    test('default --fail-on is billing', () {
      final f = fixtures();
      expect(cli(['scan', f['billing']!]).code, 1);
      expect(cli(['scan', f['review']!]).code, 0);
    });

    test('usage errors exit 2', () {
      final f = fixtures();
      expect(cli([]).code, 2);
      expect(cli(['scan']).code, 2);
      expect(cli(['bogus']).code, 2);
      expect(cli(['scan', f['clean']!, '--nope']).code, 2);
      expect(cli(['scan', f['clean']!, '--format', 'xml']).code, 2);
      expect(cli(['scan', f['clean']!, '--fail-on', 'x']).code, 2);
      expect(cli(['scan', f['clean']!, '--min-entropy', 'abc']).code, 2);
      expect(cli(['scan', f['clean']!, '--max-entry-mb', '0']).code, 2);
      expect(cli(['scan', f['clean']!, '--format']).code, 2);
    });

    test('missing path and corrupt zip exit 3', () {
      expect(cli(['scan', '/definitely/not/here.apk']).code, 3);
      final dir = tempDir();
      final bad = writeBytes('${dir.path}/bad.apk', [
        0x50,
        0x4b,
        0x03,
        0x04,
        ...List.filled(40, 9),
      ]);
      final run = cli(['scan', bad.path]);
      expect(run.code, 3);
      expect(run.err, contains('Cannot read archive'));
    });

    test('--help and --version exit 0', () {
      expect(cli(['--help']).code, 0);
      expect(cli(['scan', '--help']).code, 0);
      final v = cli(['--version']);
      expect(v.code, 0);
      expect(v.out.trim(), 'flutter-key-audit $toolVersion');
    });
  });

  test(
    '--output writes the file, keeps stdout empty and still sets the exit code',
    () {
      final f = fixtures();
      final out = '${tempDir().path}/r.json';
      final run = cli([
        'scan',
        f['billing']!,
        '--format',
        'json',
        '--output',
        out,
      ]);
      expect(run.code, 1);
      expect(run.out, isEmpty);
      expect(run.err, contains(out));
      expect((jsonDecode(File(out).readAsStringSync()) as Map)['schema'], 1);
    },
  );

  test('--output to an unwritable place exits 3', () {
    final f = fixtures();
    final run = cli([
      'scan',
      f['clean']!,
      '--output',
      '/definitely/not/here/r.txt',
    ]);
    expect(run.code, 3);
  });

  test('rules command lists 9 rules', () {
    final run = cli(['rules']);
    expect(run.code, 0);
    expect(run.out, contains('Detection rules (9)'));
    expect(run.out, contains('google-api-key'));
  });
}
