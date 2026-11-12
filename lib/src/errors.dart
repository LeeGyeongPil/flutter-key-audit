/// Error raised for problems the user can fix (bad input, missing tools).
///
/// The message is never stored in English text: only a stable [code] and its
/// [params]. The CLI turns them into a localized message at the boundary, so
/// the library stays language-neutral.
class AuditException implements Exception {
  const AuditException(this.code, [this.params = const {}, this.exitCode = 3]);

  /// Stable message key, e.g. `path_not_found`.
  final String code;

  /// Values substituted into the message template.
  final Map<String, Object?> params;

  /// Process exit code: 2 for usage errors, 3 for input or runtime errors.
  final int exitCode;

  @override
  String toString() => 'AuditException($code, $params)';
}
