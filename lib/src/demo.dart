/// The `demo` command: build two synthetic versions of the same app and scan
/// them. Everything here is a practice mock; all keys are random fakes.
library;

import 'dart:convert';
import 'dart:io';

import 'errors.dart';
import 'fake_keys.dart';
import 'finding.dart';
import 'i18n.dart';
import 'options.dart';
import 'report/table.dart';
import 'walker.dart';

/// Result of the artifact demo.
class DemoResult {
  DemoResult(this.outDir, this.direct, this.proxy);
  final String outDir;
  final ScanResult direct;
  final ScanResult proxy;
}

/// Writes `direct/` and `proxy/` artifacts under [outDir] and scans both.
///
/// `direct/` is an app that calls the AI APIs itself: an APK-shaped zip with a
/// fake `libapp.so` and a `.env` asset, a web `main.dart.js` that calls Gemini,
/// and an envied-obfuscated source file. `proxy/` is the same app after the
/// fix: it only knows its own backend URL and a public Firebase key.
DemoResult runArtifactDemo(String outDir, {FakeKeys? fake}) {
  final keys = fake ?? FakeKeys();
  final root = Directory(outDir);
  for (final name in ['direct', 'proxy']) {
    final dir = Directory('$outDir/$name');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
  root.createSync(recursive: true);

  // direct: 3 keys in the APK, 1 Gemini key in the web bundle, 1 in source.
  final directDir = '$outDir/direct';
  _write(
    '$directDir/app-release.apk',
    buildZip({
      'lib/arm64-v8a/libapp.so': buildFakeBinary(keys, [
        'Authorization: Bearer ${keys.forRule('openai-project')}',
        'x-api-key: ${keys.forRule('anthropic')}',
      ]).bytes,
      'assets/flutter_assets/.env': ascii.encode(
        'GROQ_API_KEY=${keys.forRule('groq')}\n',
      ),
      'AndroidManifest.xml': keys.filler(64),
    }),
  );
  _write(
    '$directDir/web/main.dart.js',
    ascii.encode(
      'var url="https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent?key="+"${keys.forRule('google-api-key')}";\n',
    ),
  );
  _write(
    '$directDir/src/lib/env.g.dart',
    ascii.encode(
      buildEnviedSource('openRouterKey', keys.forRule('openrouter')),
    ),
  );

  // proxy: the app only knows its backend and a public Firebase key.
  final proxyDir = '$outDir/proxy';
  _write(
    '$proxyDir/app-release.apk',
    buildZip({
      'lib/arm64-v8a/libapp.so': buildFakeBinary(keys, [
        'https://api.example.com/v1/chat',
        'authDomain: "demo-app.firebaseapp.com", projectId: "demo-app", '
            'apiKey: "${keys.forRule('google-api-key')}"',
      ]).bytes,
      'assets/flutter_assets/.env': ascii.encode(
        'BACKEND_URL=https://api.example.com\n',
      ),
    }),
  );
  _write(
    '$proxyDir/web/main.dart.js',
    ascii.encode('var backend="https://api.example.com/v1/chat";\n'),
  );
  _write(
    '$proxyDir/src/lib/env.dart',
    ascii.encode("const backendUrl = 'https://api.example.com';\n"),
  );

  ScanResult scanBoth(String dir) => ScanResult.merge([
    scanPaths(['$dir/app-release.apk', '$dir/web']),
    scanPaths(['$dir/src'], options: const ScanOptions(source: true)),
  ]);
  return DemoResult(outDir, scanBoth(directDir), scanBoth(proxyDir));
}

void _write(String path, List<int> bytes) {
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

/// Prints the artifact demo to [out].
void printArtifactDemo(DemoResult r, Lang lang, StringSink out) {
  out.writeln(t(lang, 'demo_banner'));
  out.writeln(t(lang, 'demo_out', {'path': r.outDir}));
  out.writeln();
  out.writeln(t(lang, 'demo_direct_title'));
  out.write(renderTable(r.direct, lang));
  out.writeln();
  out.writeln(t(lang, 'demo_proxy_title'));
  out.write(renderTable(r.proxy, lang));
  out.writeln();
  out.writeln(
    t(lang, 'demo_result_direct', {
      'billing': r.direct.count(Severity.billing),
      'info': r.direct.count(Severity.info),
    }),
  );
  out.writeln(
    t(lang, 'demo_result_proxy', {
      'billing': r.proxy.count(Severity.billing),
      'info': r.proxy.count(Severity.info),
    }),
  );
  out.writeln();
  out.writeln(t(lang, 'demo_lesson'));
  out.writeln(t(lang, 'demo_next'));
}

/// Small Dart program that reads a key given with `-D`, like a Flutter app
/// using `String.fromEnvironment`.
const _aotProgram = '''
const apiKey = String.fromEnvironment('OPENAI_API_KEY');

void main() {
  final headers = {'Authorization': 'Bearer \$apiKey'};
  print(headers.values.first.length);
}
''';

/// Outcome of the AOT demo for one build variant.
class AotOutcome {
  AotOutcome(this.file, this.rules);
  final String file;
  final List<String> rules;
  bool get detected => rules.contains('openai-project');
}

/// Compiles the program with a fake key twice (plain and `--obfuscate`) using
/// the real `dart compile aot-snapshot`, then scans both ELF files.
///
/// [dartCommand] is the executable to run; tests pass a missing name to
/// check the error path. Throws [AuditException] when dart is missing or the
/// compile fails.
({AotOutcome plain, AotOutcome obfuscated}) runAotDemo(
  String outDir, {
  String dartCommand = 'dart',
  FakeKeys? fake,
}) {
  final dir = Directory('$outDir/aot')..createSync(recursive: true);
  final source = File('${dir.path}/keyapp.dart')
    ..writeAsStringSync(_aotProgram);
  final key = (fake ?? FakeKeys()).forRule('openai-project');

  AotOutcome build(String name, List<String> extra) {
    final outFile = '${dir.path}/$name.aot';
    final ProcessResult res;
    try {
      res = Process.runSync(dartCommand, [
        'compile',
        'aot-snapshot',
        ...extra,
        '-DOPENAI_API_KEY=$key',
        '-o',
        outFile,
        source.path,
      ]);
    } on ProcessException {
      throw const AuditException('dart_not_found');
    }
    if (res.exitCode != 0) {
      final detail = '${res.stderr}${res.stdout}'.trim().split('\n').last;
      throw AuditException('aot_compile_failed', {'detail': detail});
    }
    final scan = scanPaths([outFile]);
    return AotOutcome(outFile, [for (final f in scan.findings) f.rule]);
  }

  return (
    plain: build('keyapp_plain', const []),
    obfuscated: build('keyapp_obfuscated', const [
      '--extra-gen-snapshot-options=--obfuscate',
    ]),
  );
}

/// Prints the AOT demo to [out].
void printAotDemo(
  ({AotOutcome plain, AotOutcome obfuscated}) r,
  Lang lang,
  StringSink out,
) {
  String status(AotOutcome o) => o.detected
      ? t(lang, 'demo_aot_detected', {'rule': 'openai-project'})
      : t(lang, 'demo_aot_not_detected');
  out.writeln(t(lang, 'demo_aot_title'));
  out.writeln(t(lang, 'demo_aot_plain', {'status': status(r.plain)}));
  out.writeln(t(lang, 'demo_aot_obfuscated', {'status': status(r.obfuscated)}));
  out.writeln(t(lang, 'demo_aot_lesson'));
}
