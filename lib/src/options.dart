import 'finding.dart';

/// Settings for a scan.
class ScanOptions {
  const ScanOptions({
    this.minEntropy = 3.0,
    this.maxEntryBytes = 512 * 1024 * 1024,
    this.excludes = const [],
    this.source = false,
  });

  /// Candidates below this Shannon entropy (bits per character) are dropped.
  final double minEntropy;

  /// Files and archive entries larger than this are skipped and counted.
  final int maxEntryBytes;

  /// Extra path fragments to skip (substring of the path inside the scan root).
  final List<String> excludes;

  /// Source mode: read text files line by line and recover envied keys
  /// instead of extracting strings from binaries.
  final bool source;
}

/// Folders skipped in source mode (relative to the scan root).
const defaultSourceExcludes = [
  '.git/',
  '.dart_tool/',
  'build/',
  'ios/Pods/',
  'node_modules/',
];

/// Counters that explain what a scan did and did not look at.
class ScanStats {
  int filesScanned = 0;
  int entriesScanned = 0;
  int entriesSkipped = 0;
  int lowEntropySkipped = 0;

  /// Symlinks to folders or broken symlinks that were not followed.
  int linksSkipped = 0;

  void add(ScanStats other) {
    linksSkipped += other.linksSkipped;
    filesScanned += other.filesScanned;
    entriesScanned += other.entriesScanned;
    entriesSkipped += other.entriesSkipped;
    lowEntropySkipped += other.lowEntropySkipped;
  }
}

/// Findings plus counters.
class ScanResult {
  ScanResult(this.findings, this.stats);

  final List<Finding> findings;
  final ScanStats stats;

  int count(Severity s) => findings.where((f) => f.severity == s).length;

  /// Joins several results (for example artifacts and source).
  factory ScanResult.merge(Iterable<ScanResult> parts) {
    final findings = <Finding>[];
    final stats = ScanStats();
    for (final p in parts) {
      findings.addAll(p.findings);
      stats.add(p.stats);
    }
    return ScanResult(findings, stats);
  }
}
