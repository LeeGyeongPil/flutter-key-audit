import 'finding.dart';

/// Host used by the Gemini Developer API.
const geminiHost = 'generativelanguage.googleapis.com';

/// Strings that sit next to a Firebase client configuration.
const firebaseMarkers = [
  'authDomain',
  'projectId',
  'storageBucket',
  'messagingSenderId',
  'firebaseapp.com',
];

/// File names that hold a Firebase client configuration.
const firebaseFiles = [
  'google-services.json',
  'GoogleService-Info.plist',
  'firebase_options.dart',
];

/// Severity of a Google API key plus the evidence that decided it.
class GoogleVerdict {
  const GoogleVerdict(this.severity, this.evidence);
  final Severity severity;
  final List<String> evidence;
}

/// Decides what an `AIza...` key is from its surroundings.
///
/// [entryName] is the file or archive entry holding the key and [texts] are
/// the printable strings (or source text) of that same file. Heuristic:
/// * the Gemini host in the same file means the key is used for Gemini, so
///   it bills money: `billing`.
/// * Firebase configuration markers mean a public Firebase key: `info`.
/// * otherwise a person has to look: `review`.
GoogleVerdict classifyGoogleKey(String entryName, Iterable<String> texts) {
  var gemini = false;
  final markers = <String>{};
  for (final text in texts) {
    if (!gemini && text.contains(geminiHost)) gemini = true;
    for (final m in firebaseMarkers) {
      if (!markers.contains(m) && text.contains(m)) markers.add(m);
    }
  }
  final base = entryName.split('/').last;
  final evidence = <String>[
    if (gemini) 'gemini_endpoint',
    for (final m in firebaseMarkers)
      if (markers.contains(m)) 'firebase_marker:$m',
    for (final f in firebaseFiles)
      if (base == f) 'firebase_file:$f',
  ];
  if (gemini) return GoogleVerdict(Severity.billing, evidence);
  if (evidence.isNotEmpty) return GoogleVerdict(Severity.info, evidence);
  return const GoogleVerdict(Severity.review, ['no_context']);
}
