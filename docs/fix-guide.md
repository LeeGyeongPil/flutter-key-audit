# Fix guide: take the AI key out of the app

Sources checked 2026-11-13: [Flutter obfuscation](https://docs.flutter.dev/deployment/obfuscate),
[Dart environment declarations](https://dart.dev/libraries/core/environment-declarations),
[Firebase API keys](https://firebase.google.com/docs/projects/api-keys),
[Firebase AI Logic and App Check](https://firebase.google.com/docs/ai-logic/app-check).

## Why hiding does not work

| Trick | What really happens |
|---|---|
| `--dart-define=OPENAI_API_KEY=...` | The value is a compile-time constant. It is stored as a plain string in `libapp.so`, `App.framework/App` or `main.dart.js`. |
| `--obfuscate` | Only symbol names are renamed. Strings stay readable. `flutter-key-audit demo --aot` shows this with a real compile. |
| `.env` as a Flutter asset | The file is copied into `flutter_assets/` inside the APK or IPA. |
| envied with `obfuscate: true` | The value is split into two integer arrays that ship together. One XOR rebuilds it. `scan --source` does exactly that. |

Anything that ships in the app can be read by whoever downloads the app. The
fix is structure: the **backend** holds the key, the app only proves who the
user is.

## Step 1: rotate the key first

A key that was in a published build must be treated as stolen, even if you
remove it from the next release.

1. Create a new key in the provider console.
2. Put the new key only on the backend (environment variable or secret store).
3. Delete the old key. Older app versions that still use it will stop working;
   that is the point.
4. Check the provider's usage page for calls you do not recognise.

## Step 2: move the call behind a backend

Before (the app holds the key):

```dart
const apiKey = String.fromEnvironment('OPENAI_API_KEY'); // ends up in the binary

final res = await http.post(
  Uri.parse('https://api.openai.com/v1/chat/completions'),
  headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
  body: jsonEncode({'model': 'gpt-4o-mini', 'messages': messages}),
);
```

After (the app calls your backend with the user's login token, no provider key):

```dart
final res = await http.post(
  Uri.parse('https://api.your-app.example/v1/chat'),
  headers: {
    'Authorization': 'Bearer ${await auth.currentUserIdToken()}', // the user, not the provider
    'Content-Type': 'application/json',
  },
  body: jsonEncode({'messages': messages}), // the backend picks model and limits
);
```

A minimal backend using only `dart:io` (the key comes from the environment of
the server, never from the app):

```dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final providerKey = Platform.environment['OPENAI_API_KEY']; // server side only
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  final client = HttpClient(); // One client for all requests, so connections are reused.
  await for (final req in server) {
    // 1. Check who is calling (verify the user's token with your auth provider).
    // 2. Apply per-user rate limits and a spending cap.
    // 3. Forward only the fields you allow.
    // Limit the body size: reject anything over 64 KB while reading.
    final body = <int>[];
    var tooLarge = req.contentLength > 64 * 1024;
    if (!tooLarge) {
      await for (final chunk in req) {
        body.addAll(chunk);
        if (body.length > 64 * 1024) {
          tooLarge = true;
          break; // stop reading as soon as the limit is passed
        }
      }
    }
    if (tooLarge) {
      req.response.statusCode = HttpStatus.requestEntityTooLarge;
      await req.response.close();
      continue;
    }
    final upstream = await client.postUrl(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
    );
    upstream.headers
      ..set('Authorization', 'Bearer $providerKey')
      ..contentType = ContentType.json;
    upstream.add(body);
    final res = await upstream.close();
    req.response.statusCode = res.statusCode;
    await res.pipe(req.response);
  }
}
```

This is a sketch, not production code: add authentication, limits and error
handling before you deploy it.

## Gemini: Firebase AI Logic with App Check

If you call Gemini, the Firebase AI Logic SDK lets the app call Gemini without
a Gemini key inside the app, and App Check rejects requests that do not come
from your genuine app. See the
[Firebase AI Logic documentation](https://firebase.google.com/docs/ai-logic/app-check).
Do not paste a Gemini Developer API key into `firebase_options.dart` or any
other client file.

## Firebase keys (`info` findings)

An `AIza...` key in `google-services.json`, `GoogleService-Info.plist` or
`firebase_options.dart` is a public client identifier by design. Still:

- Restrict it to your app (Android package name and SHA-1, iOS bundle ID).
- In Google Cloud, **API restrictions**: remove *Generative Language API* from the
  allow list. Otherwise this public key can also bill Gemini calls.

## Review findings

A `review` finding is an `AIza...` key with no Firebase or Gemini hint nearby.
Open the key in Google Cloud and check its restrictions. If it can call the
Generative Language API, rotate it and follow Step 2.

## Check again

```sh
flutter build apk --release
flutter-key-audit scan build/app/outputs/flutter-apk/app-release.apk --fail-on billing
```

Exit code 0 means no billable key was found in that file. It does not prove the
app is safe: the tool is offline and cannot tell whether a key is still alive.

## Run it in CI

```yaml
- run: flutter build web --release
- run: flutter-key-audit scan build/web --format sarif --output fka.sarif --fail-on billing
- uses: github/codeql-action/upload-sarif@v4
  if: always()
  with:
    sarif_file: fka.sarif
```
