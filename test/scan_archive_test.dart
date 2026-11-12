import 'dart:io';

import 'package:flutter_key_audit/flutter_key_audit.dart';
import 'package:flutter_key_audit/src/fake_keys.dart';
import 'package:test/test.dart';

import 'helpers/fixtures.dart';

void main() {
  group('APK-shaped zip', () {
    test('finds 3 billing keys with archive path and byte offset', () {
      final dir = tempDir();
      final apk = buildApk('${dir.path}/app-release.apk');
      final result = scanPaths([apk.file.path]);

      expect(result.findings, hasLength(3));
      final byRule = {for (final f in result.findings) f.rule: f};
      expect(byRule.keys, {'openai-project', 'anthropic', 'groq'});

      final openai = byRule['openai-project']!;
      expect(openai.location.path, '${apk.file.path}!/lib/arm64-v8a/libapp.so');
      expect(openai.location.offset, apk.openaiOffset);
      expect(openai.raw, apk.openai);
      expect(byRule['anthropic']!.location.offset, apk.anthropicOffset);
      expect(
        byRule['groq']!.location.path,
        '${apk.file.path}!/assets/flutter_assets/.env',
      );
      expect(byRule['groq']!.location.offset, groqPrefix.length);
      expect(
        result.findings.every((f) => f.severity == Severity.billing),
        isTrue,
      );
      expect(result.stats.entriesScanned, 3);
    });

    test('the same zip renamed to .bin is opened by magic bytes', () {
      final dir = tempDir();
      final apk = buildApk('${dir.path}/app-release.apk');
      final copy = apk.file.copySync('${dir.path}/renamed.bin');
      final result = scanPaths([copy.path]);

      expect(result.findings, hasLength(3));
      expect(result.findings.map((f) => f.rule).toSet(), {
        'openai-project',
        'anthropic',
        'groq',
      });
      expect(result.findings.first.location.path, contains('renamed.bin!/'));
    });

    test('AAB layout (base/lib) and IPA layout (App.framework) work too', () {
      final dir = tempDir();
      final aab = buildApk(
        '${dir.path}/app.aab',
        libEntry: 'base/lib/arm64-v8a/libapp.so',
      );
      expect(scanPaths([aab.file.path]).findings, hasLength(3));

      final fake = FakeKeys();
      final key = fake.forRule('xai');
      // Mach-O 64-bit magic instead of ELF.
      final macho = buildFakeBinary(fake, ['token=$key'], elf: false);
      final ipa = writeBytes(
        '${dir.path}/app.ipa',
        buildZip({
          'Payload/Runner.app/Frameworks/App.framework/App': [
            0xcf,
            0xfa,
            0xed,
            0xfe,
            ...macho.bytes,
          ],
        }),
      );
      final found = scanPaths([ipa.path]).findings;
      expect(found.single.rule, 'xai');
      expect(
        found.single.location.path,
        endsWith('!/Payload/Runner.app/Frameworks/App.framework/App'),
      );
      expect(found.single.location.offset, macho.offsets.single + 4 + 6);
    });
  });

  group('folders and files', () {
    test('build/web shaped folder is scanned recursively', () {
      final dir = tempDir();
      final key = FakeKeys().forRule('huggingface');
      writeText('${dir.path}/build/web/main.dart.js', 'var t="$key";\n');
      writeText('${dir.path}/build/web/index.html', '<html></html>');
      final result = scanPaths(['${dir.path}/build/web']);
      expect(result.findings.single.rule, 'huggingface');
      expect(
        result.findings.single.location.path,
        '${dir.path}/build/web/main.dart.js',
      );
      // Artifact folders are not filtered: the build/ part of the root path
      // and a build/ folder inside are both fine.
      expect(result.stats.filesScanned, 2);
    });

    test('a single AOT-like file is scanned as binary', () {
      final dir = tempDir();
      final key = FakeKeys().forRule('replicate');
      final bin = buildFakeBinary(FakeKeys(), ['k=$key']);
      final file = writeBytes('${dir.path}/libapp.so', bin.bytes);
      final f = scanPaths([file.path]).findings.single;
      expect(f.rule, 'replicate');
      expect(f.location.offset, bin.offsets.single + 2);
    });

    test('a key followed by printable garbage is still found in binaries', () {
      final dir = tempDir();
      final key = FakeKeys().forRule('groq');
      final file = writeBytes(
        '${dir.path}/libapp.so',
        buildFakeBinary(FakeKeys(), ['$key!!junk']).bytes,
      );
      expect(scanPaths([file.path]).findings.single.rule, 'groq');
    });
  });

  group('limits and errors', () {
    test('entries above the size limit are skipped and counted', () {
      final dir = tempDir();
      final apk = buildApk('${dir.path}/a.apk');
      final result = scanPaths([
        apk.file.path,
      ], options: const ScanOptions(maxEntryBytes: 100));
      expect(result.stats.entriesSkipped, greaterThan(0));
      expect(result.findings.length, lessThan(3));
    });

    test(
      'symlinked files are followed once; folder and broken links counted',
      () {
        final dir = tempDir();
        final apk = buildApk('${dir.path}/real.apk');
        final scan = Directory('${dir.path}/scan')..createSync();
        Link('${scan.path}/a.apk').createSync(apk.file.path);
        Link('${scan.path}/b.apk').createSync(apk.file.path); // same target
        Link('${scan.path}/dir').createSync(dir.path); // folder link
        Link('${scan.path}/gone').createSync('${dir.path}/missing');
        final result = scanPaths([scan.path]);
        expect(result.findings, hasLength(3));
        expect(result.stats.linksSkipped, 2);
      },
    );

    test('missing path throws path_not_found', () {
      expect(
        () => scanPaths(['/definitely/not/here.apk']),
        throwsA(
          isA<AuditException>().having((e) => e.code, 'code', 'path_not_found'),
        ),
      );
    });

    test('zip magic with a damaged body throws corrupt_zip', () {
      final dir = tempDir();
      final file = writeBytes('${dir.path}/bad.apk', [
        0x50,
        0x4b,
        0x03,
        0x04,
        ...List.filled(40, 7),
      ]);
      expect(
        () => scanPaths([file.path]),
        throwsA(
          isA<AuditException>().having((e) => e.code, 'code', 'corrupt_zip'),
        ),
      );
    });
  });
}
