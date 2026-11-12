import 'messages_en.dart';
import 'messages_ko.dart';

/// Output languages.
enum Lang { en, ko }

/// Environment variable that sets the language for this tool.
const langEnvVar = 'FLUTTER_KEY_AUDIT_LANG';

/// Parses `en` / `ko`; returns null for anything else.
Lang? parseLang(String? value) {
  switch (value) {
    case 'en':
      return Lang.en;
    case 'ko':
      return Lang.ko;
  }
  return null;
}

/// Decides the output language.
///
/// Order: [flag] (`--lang`) > `FLUTTER_KEY_AUDIT_LANG` > `LC_ALL` >
/// `LC_MESSAGES` > `LANG`. The first non-empty value wins; a value starting
/// with `ko` means Korean, anything else means English.
Lang resolveLang(String? flag, Map<String, String> environment) {
  final fromFlag = parseLang(flag);
  if (fromFlag != null) return fromFlag;
  for (final name in [langEnvVar, 'LC_ALL', 'LC_MESSAGES', 'LANG']) {
    final value = environment[name];
    if (value != null && value.isNotEmpty) {
      return value.toLowerCase().startsWith('ko') ? Lang.ko : Lang.en;
    }
  }
  return Lang.en;
}

/// The message table for [lang].
Map<String, String> catalog(Lang lang) =>
    lang == Lang.ko ? messagesKo : messagesEn;

/// Looks up message [key] in [lang] and fills `{name}` placeholders.
/// An unknown key is returned as is so a missing message is visible.
String t(Lang lang, String key, [Map<String, Object?> params = const {}]) {
  var text = catalog(lang)[key] ?? key;
  params.forEach((name, value) {
    text = text.replaceAll('{$name}', '$value');
  });
  return text;
}
