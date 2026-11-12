/// Generators for synthetic artifacts and random fake keys.
///
/// Used by the `demo` command and by the tests. Every key is assembled at run
/// time (prefix + random characters), so the repository never contains a
/// string that looks like a real key and other secret scanners stay quiet.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'rules.dart';

const _alnum = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const _urlsafe = '$_alnum-_';
const _hex = '0123456789abcdef';

/// Builds random fake keys in each provider's format.
class FakeKeys {
  FakeKeys([Random? random]) : _r = random ?? Random.secure();

  final Random _r;

  String _pick(String alphabet, int n) =>
      List.generate(n, (_) => alphabet[_r.nextInt(alphabet.length)]).join();

  /// A random key for [ruleId]; pass [marker] false for an OpenAI project
  /// key without the `T3BlbkFJ` marker. Retries until the key passes the
  /// default entropy filter.
  String forRule(String ruleId, {bool marker = true}) {
    for (var i = 0; i < 50; i++) {
      final key = _build(ruleId, marker);
      if (shannonEntropy(key) >= 3.5) return key;
    }
    throw StateError('could not generate a high-entropy key for $ruleId');
  }

  String _build(String ruleId, bool marker) {
    switch (ruleId) {
      case 'anthropic':
        return 'sk-ant-'
            'api03-${_pick(_urlsafe, 93)}';
      case 'openai-project':
        return marker
            ? 'sk-proj-${_pick(_urlsafe, 60)}$openAiMarker${_pick(_urlsafe, 40)}'
            : 'sk-proj-${_pick(_urlsafe, 100)}';
      case 'openai-legacy':
        return 'sk-${_pick(_alnum, 20)}$openAiMarker${_pick(_alnum, 20)}';
      case 'openrouter':
        return 'sk-or-v1-${_pick(_hex, 64)}';
      case 'groq':
        return 'gsk'
            '_${_pick(_alnum, 52)}';
      case 'huggingface':
        return 'hf'
            '_${_pick(_alnum, 34)}';
      case 'replicate':
        return 'r8'
            '_${_pick(_alnum, 37)}';
      case 'xai':
        return 'xai-${_pick(_alnum, 80)}';
      case 'google-api-key':
        return 'AIza${_pick(_urlsafe, 35)}';
    }
    throw ArgumentError('unknown rule id: $ruleId');
  }

  /// Random bytes that are never printable ASCII (like machine code).
  Uint8List filler(int n) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      // 0x00-0x1f or 0x80-0xff: never part of a printable run.
      final v = _r.nextInt(32 + 128);
      out[i] = v < 32 ? v : 0x80 + (v - 32);
    }
    return out;
  }
}

/// A synthetic binary and where each snippet starts.
class FakeBinary {
  FakeBinary(this.bytes, this.offsets);
  final Uint8List bytes;

  /// Offset of each snippet, in the order given to [buildFakeBinary].
  final List<int> offsets;
}

/// Builds a fake AOT snapshot: an ELF header, then each of [snippets] (Dart
/// constant strings) separated by non-printable filler, like libapp.so.
FakeBinary buildFakeBinary(
  FakeKeys fake,
  List<String> snippets, {
  bool elf = true,
  int gap = 64,
}) {
  final out = BytesBuilder();
  if (elf) out.add([0x7f, 0x45, 0x4c, 0x46, 2, 1, 1, 0]);
  final offsets = <int>[];
  for (final s in snippets) {
    out.add(fake.filler(gap));
    offsets.add(out.length);
    out.add(ascii.encode(s));
  }
  out.add(fake.filler(gap));
  return FakeBinary(out.toBytes(), offsets);
}

/// Packs [entries] (name to bytes) into zip bytes, like an APK or IPA.
Uint8List buildZip(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach((name, data) {
    archive.addFile(ArchiveFile(name, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Writes an envied-style `*.g.dart` file: [value] split into a random key
/// array and an XOR data array, the same shape envied_generator 1.3.10
/// produces with `obfuscate: true`.
String buildEnviedSource(String field, String value, [Random? random]) {
  final r = random ?? Random.secure();
  final key = [for (var i = 0; i < value.length; i++) r.nextInt(1 << 32)];
  final data = [
    for (var i = 0; i < value.length; i++) value.codeUnitAt(i) ^ key[i],
  ];
  return '// GENERATED CODE - DO NOT MODIFY BY HAND\n'
      "part of 'env.dart';\n"
      'final class _Env {\n'
      '  static const List<int> _enviedkey$field = <int>[${key.join(', ')}];\n'
      '  static const List<int> _envieddata$field = <int>[${data.join(', ')}];\n'
      '  static final String $field = String.fromCharCodes(List<int>.generate(\n'
      '    _envieddata$field.length, (int i) => i, growable: false,\n'
      '  ).map((int i) => _envieddata$field[i] ^ _enviedkey$field[i]));\n'
      '}\n';
}
