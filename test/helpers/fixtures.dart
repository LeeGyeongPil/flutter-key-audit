// Test helpers: temp folders, generated artifacts and a CLI runner.
//
// No key-shaped string is stored in the repository. Every fake key is built at
// run time by FakeKeys (prefix + random characters).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_key_audit/src/cli.dart';
import 'package:flutter_key_audit/src/fake_keys.dart';
import 'package:test/test.dart';

/// English fixed, whatever LANG the machine has.
const enEnv = {'FLUTTER_KEY_AUDIT_LANG': 'en'};

/// Output of one in-process CLI run.
class CliRun {
  CliRun(this.code, this.out, this.err);
  final int code;
  final String out;
  final String err;
}

/// Runs the CLI in this process with an injected environment.
CliRun cli(
  List<String> args, {
  Map<String, String> env = enEnv,
  String dartCommand = 'dart',
}) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runCli(
    args,
    environment: env,
    out: out,
    err: err,
    dartCommand: dartCommand,
  );
  return CliRun(code, out.toString(), err.toString());
}

/// A temp folder that is removed after the current test.
Directory tempDir() {
  final dir = Directory.systemTemp.createTempSync('fka-test-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

File writeBytes(String path, List<int> bytes) => File(path)
  ..createSync(recursive: true)
  ..writeAsBytesSync(bytes);

File writeText(String path, String text) => writeBytes(path, utf8.encode(text));

/// An APK-shaped zip plus the keys and offsets it contains.
class ApkFixture {
  ApkFixture(
    this.file,
    this.openai,
    this.anthropic,
    this.groq,
    this.openaiOffset,
    this.anthropicOffset,
  );
  final File file;
  final String openai;
  final String anthropic;
  final String groq;

  /// Offsets inside `lib/arm64-v8a/libapp.so`.
  final int openaiOffset;
  final int anthropicOffset;

  List<String> get keys => [openai, anthropic, groq];
}

const openaiPrefix = 'Authorization: Bearer ';
const anthropicPrefix = 'x-api-key: ';
const groqPrefix = 'GROQ_API_KEY=';

/// APK with a fake libapp.so (openai-project + anthropic) and a .env (groq).
ApkFixture buildApk(
  String path, {
  String libEntry = 'lib/arm64-v8a/libapp.so',
}) {
  final fake = FakeKeys();
  final openai = fake.forRule('openai-project');
  final anthropic = fake.forRule('anthropic');
  final groq = fake.forRule('groq');
  final bin = buildFakeBinary(fake, [
    '$openaiPrefix$openai',
    '$anthropicPrefix$anthropic',
  ]);
  final zip = buildZip({
    libEntry: bin.bytes,
    'assets/flutter_assets/.env': ascii.encode('$groqPrefix$groq\n'),
    'AndroidManifest.xml': fake.filler(32),
  });
  final file = writeBytes(path, zip);
  return ApkFixture(
    file,
    openai,
    anthropic,
    groq,
    bin.offsets[0] + openaiPrefix.length,
    bin.offsets[1] + anthropicPrefix.length,
  );
}

/// Bytes of a fake binary holding [snippets].
Uint8List binaryWith(List<String> snippets) =>
    buildFakeBinary(FakeKeys(), snippets).bytes;

/// Reads a text file.
String readFile(String path) => File(path).readAsStringSync();
