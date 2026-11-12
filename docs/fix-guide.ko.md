# 고치는 법: AI 키를 앱 밖으로 빼기

확인한 자료(2026-11-13): [Flutter 난독화](https://docs.flutter.dev/deployment/obfuscate),
[Dart 환경 선언](https://dart.dev/libraries/core/environment-declarations),
[Firebase API 키](https://firebase.google.com/docs/projects/api-keys),
[Firebase AI Logic 과 App Check](https://firebase.google.com/docs/ai-logic/app-check).

## 숨겨도 소용없는 이유

| 방법 | 실제로 일어나는 일 |
|---|---|
| `--dart-define=OPENAI_API_KEY=...` | 값은 컴파일 시점 상수입니다. `libapp.so`, `App.framework/App`, `main.dart.js` 안에 평문 문자열로 들어갑니다. |
| `--obfuscate` | 심볼 이름만 바뀝니다. 문자열은 그대로 읽힙니다. `flutter-key-audit demo --aot` 가 실제 컴파일로 보여 줍니다. |
| `.env` 를 Flutter 자산으로 포함 | 파일이 APK·IPA 의 `flutter_assets/` 에 그대로 복사됩니다. |
| envied `obfuscate: true` | 값이 정수 배열 두 개로 나뉘어 함께 배포됩니다. XOR 한 번이면 복원됩니다. `scan --source` 가 그대로 합니다. |

앱에 실려 나가는 것은 앱을 내려받은 누구나 읽을 수 있습니다. 해결책은 구조입니다.
키는 **백엔드**가 가지고, 앱은 사용자가 누구인지만 증명합니다.

## 1단계: 먼저 키를 회전합니다

배포된 빌드에 들어 있던 키는 다음 릴리스에서 지우더라도 유출된 것으로 봐야 합니다.

1. 제공자 콘솔에서 새 키를 만듭니다.
2. 새 키는 백엔드(환경 변수 또는 비밀 저장소)에만 둡니다.
3. 예전 키를 삭제합니다. 그 키를 쓰던 옛 앱 버전은 동작하지 않게 되며, 그것이 목적입니다.
4. 제공자의 사용량 페이지에서 모르는 호출이 있는지 확인합니다.

## 2단계: 호출을 백엔드 뒤로 옮깁니다

이전(앱이 키를 가짐):

```dart
const apiKey = String.fromEnvironment('OPENAI_API_KEY'); // 바이너리에 들어갑니다

final res = await http.post(
  Uri.parse('https://api.openai.com/v1/chat/completions'),
  headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
  body: jsonEncode({'model': 'gpt-4o-mini', 'messages': messages}),
);
```

이후(앱은 사용자 로그인 토큰으로 내 백엔드를 호출하고 제공자 키는 없음):

```dart
final res = await http.post(
  Uri.parse('https://api.your-app.example/v1/chat'),
  headers: {
    'Authorization': 'Bearer ${await auth.currentUserIdToken()}', // 제공자가 아니라 사용자
    'Content-Type': 'application/json',
  },
  body: jsonEncode({'messages': messages}), // 모델과 한도는 백엔드가 정합니다
);
```

`dart:io` 만 쓰는 최소 백엔드입니다(키는 서버의 환경 변수에서 읽고 앱에서는 받지 않습니다).

```dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final providerKey = Platform.environment['OPENAI_API_KEY']; // 서버에만 있음
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  final client = HttpClient(); // 요청마다 새로 만들지 않고 클라이언트 하나를 재사용합니다.
  await for (final req in server) {
    // 1. 호출자가 누구인지 확인합니다(인증 제공자로 사용자 토큰 검증).
    // 2. 사용자별 호출 제한과 비용 상한을 둡니다.
    // 3. 허용한 필드만 전달합니다.
    // 본문 크기를 제한하세요: 본문을 읽는 도중 64KB 를 넘으면 거절합니다.
    final body = <int>[];
    var tooLarge = req.contentLength > 64 * 1024;
    if (!tooLarge) {
      await for (final chunk in req) {
        body.addAll(chunk);
        if (body.length > 64 * 1024) {
          tooLarge = true;
          break; // 한도를 넘으면 바로 읽기를 멈춥니다
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

스케치일 뿐 운영 코드가 아닙니다. 배포 전에 인증, 호출 제한, 오류 처리를 추가하세요.

## Gemini: Firebase AI Logic 과 App Check

Gemini 를 쓴다면 Firebase AI Logic SDK 로 앱 안에 Gemini 키 없이 호출할 수 있고,
App Check 가 정품 앱이 아닌 요청을 거절합니다.
[Firebase AI Logic 문서](https://firebase.google.com/docs/ai-logic/app-check)를 보세요.
Gemini Developer API 키를 `firebase_options.dart` 나 다른 클라이언트 파일에 넣지 마세요.

## Firebase 키(`참고` 등급)

`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart` 안의
`AIza...` 키는 설계상 공개되는 클라이언트 식별자입니다. 그래도 다음은 해 두세요.

- 앱으로 사용 제한을 겁니다(Android 패키지 이름과 SHA-1, iOS 번들 ID).
- Google Cloud 의 **API 제한**에서 *Generative Language API* 를 허용 목록에서 뺍니다.
  그렇지 않으면 이 공개 키로 Gemini 호출 비용이 청구될 수 있습니다.

## 확인 필요 등급

`확인 필요` 는 주변에 Firebase 나 Gemini 단서가 없는 `AIza...` 키입니다.
Google Cloud 에서 키의 제한을 열어 보세요. Generative Language API 를 호출할 수 있으면
회전하고 2단계를 따르세요.

## 다시 확인합니다

```sh
flutter build apk --release
flutter-key-audit scan build/app/outputs/flutter-apk/app-release.apk --fail-on billing
```

종료 코드 0 은 그 파일에서 과금 키를 찾지 못했다는 뜻입니다. 앱이 안전하다는 증명은 아닙니다.
이 도구는 오프라인이라 키가 아직 살아 있는지 알 수 없습니다.

## CI 에서 돌리기

```yaml
- run: flutter build web --release
- run: flutter-key-audit scan build/web --format sarif --output fka.sarif --fail-on billing
- uses: github/codeql-action/upload-sarif@v4
  if: always()
  with:
    sarif_file: fka.sarif
```
