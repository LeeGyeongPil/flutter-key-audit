import 'dart:typed_data';

/// A run of printable ASCII bytes and the file offset where it starts.
class PrintableRun {
  const PrintableRun(this.offset, this.text);
  final int offset;
  final String text;
}

/// Extracts printable ASCII runs (0x20-0x7e) of at least [minLength] bytes,
/// like `strings -n 8`. Works on any binary: ELF, Mach-O, JavaScript, zip
/// entries. No format parsing is needed because Dart string constants are
/// stored as plain one-byte strings in the AOT snapshot.
Iterable<PrintableRun> printableRuns(
  Uint8List bytes, {
  int minLength = 8,
}) sync* {
  var start = -1;
  for (var i = 0; i <= bytes.length; i++) {
    final printable = i < bytes.length && bytes[i] >= 0x20 && bytes[i] < 0x7f;
    if (printable) {
      if (start < 0) start = i;
    } else if (start >= 0) {
      if (i - start >= minLength) {
        yield PrintableRun(start, String.fromCharCodes(bytes, start, i));
      }
      start = -1;
    }
  }
}
