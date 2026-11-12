import 'dart:io';

import 'package:flutter_key_audit/src/demo.dart';
import 'package:flutter_key_audit/src/finding.dart';
import 'package:test/test.dart';

import 'helpers/fixtures.dart';

void main() {
  test('demo: direct has 5 billing, proxy has 0 billing and 1 info', () {
    final dir = tempDir();
    final r = runArtifactDemo(dir.path);
    expect(r.direct.count(Severity.billing), 5);
    expect(r.proxy.count(Severity.billing), 0);
    expect(r.proxy.count(Severity.info), 1);
    expect(r.proxy.findings.single.rule, 'google-api-key');
    // The envied key is found only through source mode.
    expect(
      r.direct.findings.where((f) => f.recovered == 'envied'),
      hasLength(1),
    );
    expect(File('${dir.path}/direct/app-release.apk').existsSync(), isTrue);
  });

  test('demo command says it is a practice mock and prints both results', () {
    final dir = tempDir();
    final run = cli(['demo', '--lang', 'en', '--out', dir.path]);
    expect(run.code, 0);
    expect(run.out, contains('practice mock'));
    expect(run.out, contains('direct: 5 billing'));
    expect(run.out, contains('proxy: 0 billing, 1 info'));
  });

  test('demo is also a practice mock in Korean', () {
    final dir = tempDir();
    final run = cli(['demo', '--lang', 'ko', '--out', dir.path]);
    expect(run.code, 0);
    expect(run.out, contains('연습용 목'));
    expect(run.out, contains('direct: 과금 5건'));
  });

  test('demo output never prints a raw demo key', () {
    final dir = tempDir();
    final run = cli(['demo', '--out', dir.path]);
    // Every .env value in the generated direct APK is redacted in the output.
    expect(run.out, isNot(contains('GROQ_API_KEY=')));
  });

  test(
    'demo --aot compiles for real and detects the key in both ELF files',
    () {
      final dir = tempDir();
      final run = cli([
        'demo',
        '--aot',
        '--lang',
        'en',
        '--out',
        dir.path,
      ], dartCommand: Platform.resolvedExecutable);
      expect(run.err, isEmpty);
      expect(run.out, contains('aot plain: detected'));
      expect(run.out, contains('aot obfuscated: detected'));
      expect(run.code, 0);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'demo --aot without dart on PATH gives a localized error and exit 3',
    () {
      final dir = tempDir();
      final en = cli([
        'demo',
        '--aot',
        '--out',
        dir.path,
      ], dartCommand: 'no-such-dart-command-xyz');
      expect(en.code, 3);
      expect(en.err, contains('The dart command was not found'));
      final ko = cli([
        'demo',
        '--aot',
        '--lang',
        'ko',
        '--out',
        dir.path,
      ], dartCommand: 'no-such-dart-command-xyz');
      expect(ko.code, 3);
      expect(ko.err, contains('dart 명령을 찾을 수 없습니다'));
    },
  );
}
