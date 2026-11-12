import 'package:flutter_key_audit/flutter_key_audit.dart';
import 'package:flutter_key_audit/src/fake_keys.dart';
import 'package:test/test.dart';

import 'helpers/fixtures.dart';

void main() {
  const source = ScanOptions(source: true);
  final fake = FakeKeys();

  test('envied XOR arrays are recovered to the original key', () {
    final dir = tempDir();
    final original = fake.forRule('openai-project');
    writeText(
      '${dir.path}/lib/env.g.dart',
      buildEnviedSource('openaiKey', original),
    );

    final f = scanPaths([dir.path], options: source).findings.single;
    expect(f.raw, original);
    expect(f.rule, 'openai-project');
    expect(f.recovered, 'envied');
    expect(f.context, contains('envied_field:openaiKey'));
    expect(f.fix, 'envied_is_not_encryption');
    // Line of the _envieddata array in the generated file.
    expect(f.location.line, 5);
    expect(f.location.offset, isNull);
  });

  test('.env line numbers and Dart string literals are reported', () {
    final dir = tempDir();
    final groq = fake.forRule('groq');
    final hf = fake.forRule('huggingface');
    writeText('${dir.path}/.env', 'NAME=demo\n\nGROQ_API_KEY=$groq\n');
    writeText(
      '${dir.path}/lib/main.dart',
      "void main() {\n  // call\n  const token = '$hf';\n}\n",
    );

    final result = scanPaths([dir.path], options: source);
    final byRule = {for (final f in result.findings) f.rule: f};
    expect(byRule.keys, {'groq', 'huggingface'});
    expect(byRule['groq']!.location.line, 3);
    expect(byRule['groq']!.context, contains('source:dotenv'));
    expect(byRule['huggingface']!.location.line, 3);
    expect(byRule['huggingface']!.context, contains('source:dart'));
    expect(byRule['huggingface']!.location.path, '${dir.path}/lib/main.dart');
  });

  test(
    'build/, .dart_tool/, .git/, ios/Pods and node_modules are excluded',
    () {
      final dir = tempDir();
      for (final path in [
        'build/web/main.dart.js',
        '.dart_tool/cache/a.dart',
        '.git/config',
        'ios/Pods/x/y.txt',
        'node_modules/p/index.js',
      ]) {
        writeText('${dir.path}/$path', 'k=${fake.forRule('groq')}\n');
      }
      writeText('${dir.path}/lib/ok.dart', 'const a = 1;\n');
      final result = scanPaths([dir.path], options: source);
      expect(result.findings, isEmpty);
      expect(result.stats.filesScanned, 1);
    },
  );

  test('--exclude skips extra paths', () {
    final dir = tempDir();
    writeText('${dir.path}/secrets/a.env', 'k=${fake.forRule('groq')}\n');
    writeText(
      '${dir.path}/lib/b.dart',
      "const s = '${fake.forRule('xai')}';\n",
    );
    final result = scanPaths([
      dir.path,
    ], options: const ScanOptions(source: true, excludes: ['secrets/']));
    expect(result.findings.single.rule, 'xai');
  });

  test('placeholder keys are skipped and counted', () {
    final dir = tempDir();
    writeText('${dir.path}/.env', 'GROQ_API_KEY=gsk_${'a' * 52}\n');
    final result = scanPaths([dir.path], options: source);
    expect(result.findings, isEmpty);
    expect(result.stats.lowEntropySkipped, 1);
  });

  test('trailing boundary applies in source mode', () {
    final dir = tempDir();
    writeText('${dir.path}/.env', 'K=${fake.forRule('groq')}extra\n');
    expect(scanPaths([dir.path], options: source).findings, isEmpty);
  });

  test(
    'Google key in source: firebase_options.dart is info, .env is review',
    () {
      final dir = tempDir();
      writeText(
        '${dir.path}/lib/firebase_options.dart',
        "apiKey: '${fake.forRule('google-api-key')}',\n",
      );
      writeText('${dir.path}/.env', 'G=${fake.forRule('google-api-key')}\n');
      final result = scanPaths([dir.path], options: source);
      final bySeverity = {
        for (final f in result.findings)
          f.location.path.split('/').last: f.severity,
      };
      expect(bySeverity['firebase_options.dart'], Severity.info);
      expect(bySeverity['.env'], Severity.review);
    },
  );

  test('binary files in source mode are ignored', () {
    final dir = tempDir();
    writeBytes(
      '${dir.path}/blob.dat',
      binaryWith(['k=${fake.forRule('groq')}']),
    );
    expect(scanPaths([dir.path], options: source).findings, isEmpty);
  });
}
