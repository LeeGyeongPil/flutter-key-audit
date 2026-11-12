import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

import 'context.dart';
import 'errors.dart';
import 'extract.dart';
import 'finding.dart';
import 'options.dart';
import 'rules.dart';
import 'source_mode.dart';

/// Scans files, folders and zip archives (APK, AAB, IPA, zip) for AI keys.
///
/// Archives are recognised by their magic bytes (`PK\x03\x04`), not by file
/// extension, so a renamed `.bin` copy is still opened.
/// Throws [AuditException] for missing paths and corrupt archives.
ScanResult scanPaths(
  List<String> paths, {
  ScanOptions options = const ScanOptions(),
}) {
  final scanner = _Scanner(options);
  for (final path in paths) {
    scanner.scanRoot(path);
  }
  return ScanResult(scanner.findings, scanner.stats);
}

bool _hasZipMagic(Uint8List head) =>
    head.length >= 4 &&
    head[0] == 0x50 &&
    head[1] == 0x4b &&
    head[2] == 0x03 &&
    head[3] == 0x04;

class _Scanner {
  _Scanner(this.options);

  final ScanOptions options;
  final findings = <Finding>[];
  final stats = ScanStats();

  /// Real paths of files already scanned through a symlink (avoids repeats).
  final _seenLinkTargets = <String>{};

  void scanRoot(String path) {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.notFound:
        throw AuditException('path_not_found', {'path': path});
      case FileSystemEntityType.directory:
        _walkDirectory(Directory(path), path, '');
      case _:
        _scanFile(File(path), path, File(path).uri.pathSegments.last);
    }
  }

  bool _excluded(String relative) {
    final rel = '/$relative';
    if (options.source) {
      for (final frag in defaultSourceExcludes) {
        if (rel.contains('/$frag') || '$rel/'.contains('/$frag')) return true;
      }
    }
    for (final frag in options.excludes) {
      if (relative.contains(frag)) return true;
    }
    return false;
  }

  void _walkDirectory(Directory dir, String display, String relative) {
    final children = dir.listSync(followLinks: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final child in children) {
      final name = child.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final rel = relative.isEmpty ? name : '$relative/$name';
      if (_excluded(rel)) continue;
      final childDisplay = display.endsWith('/')
          ? '$display$name'
          : '$display/$name';
      if (child is Directory) {
        _walkDirectory(child, childDisplay, rel);
      } else if (child is File) {
        _scanFile(child, childDisplay, name);
      } else if (child is Link) {
        _scanLink(child, childDisplay, name);
      }
    }
  }

  /// Follows a symlink to a file once; folder links and broken links are
  /// counted in the summary instead of being skipped silently.
  void _scanLink(Link link, String display, String name) {
    final String real;
    try {
      real = link.resolveSymbolicLinksSync();
    } on FileSystemException {
      stats.linksSkipped++; // broken link
      return;
    }
    if (FileSystemEntity.typeSync(real) != FileSystemEntityType.file) {
      stats.linksSkipped++; // folder links are not followed (loop risk)
      return;
    }
    if (!_seenLinkTargets.add(real)) return;
    _scanFile(File(real), display, name);
  }

  void _scanFile(File file, String display, String name) {
    final size = file.lengthSync();
    if (size > options.maxEntryBytes) {
      stats.entriesSkipped++;
      return;
    }
    final head = _readHead(file);
    if (!options.source && _hasZipMagic(head)) {
      _scanZip(file, display);
      return;
    }
    final bytes = file.readAsBytesSync();
    stats.filesScanned++;
    if (options.source) {
      if (_looksBinary(bytes)) return;
      findings.addAll(
        scanSourceText(
          displayPath: display,
          fileName: name,
          text: String.fromCharCodes(bytes),
          options: options,
          stats: stats,
        ),
      );
    } else {
      _scanBinary(display, name, bytes);
    }
  }

  Uint8List _readHead(File file) {
    final raf = file.openSync();
    try {
      return raf.readSync(4);
    } finally {
      raf.closeSync();
    }
  }

  bool _looksBinary(Uint8List bytes) {
    final n = bytes.length < 8000 ? bytes.length : 8000;
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }

  void _scanZip(File file, String display) {
    stats.filesScanned++;
    final input = InputFileStream(file.path);
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input, throwOnError: true);
      } on Object {
        throw AuditException('corrupt_zip', {'path': display});
      }
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        if (entry.size > options.maxEntryBytes) {
          stats.entriesSkipped++;
          continue;
        }
        final Uint8List data;
        try {
          data = entry.readBytes() ?? Uint8List(0);
        } on Object {
          throw AuditException('corrupt_zip', {'path': display});
        }
        stats.entriesScanned++;
        _scanBinary('$display!/${entry.name}', entry.name, data);
        entry.clear(); // free the decompressed bytes before the next entry
      }
    } finally {
      input.closeSync();
    }
  }

  /// Binary mode: extract printable runs and match the rules on each run.
  void _scanBinary(String location, String entryName, Uint8List bytes) {
    final pending = <(RuleMatch, int)>[];
    for (final run in printableRuns(bytes)) {
      for (final m in matchRules(
        run.text,
        minEntropy: options.minEntropy,
        onLowEntropy: () => stats.lowEntropySkipped++,
      )) {
        pending.add((m, run.offset + m.start));
      }
    }
    if (pending.isEmpty) return;
    GoogleVerdict? verdict;
    for (final (m, offset) in pending) {
      var severity = m.rule.severity;
      var context = <String>[];
      if (m.rule.id == 'google-api-key') {
        // Second pass over the same entry to look for Gemini / Firebase hints.
        verdict ??= classifyGoogleKey(
          entryName,
          printableRuns(bytes).map((r) => r.text),
        );
        severity = verdict.severity;
        context = verdict.evidence;
      }
      findings.add(
        Finding(
          rule: m.rule.id,
          severity: severity,
          confidence: confidenceFor(m.rule, m.text),
          raw: m.text,
          location: Location(location, offset: offset),
          fix: fixFor(rule: m.rule.id, severity: severity),
          context: context,
        ),
      );
    }
  }
}
