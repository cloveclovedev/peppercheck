# Phase 2 Flutter — Identity & Client Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Flutter authenticated-user path off Supabase Auth onto Firebase Auth + the Go API: one shared HTTP client, a Firebase Google/Apple sign-in adapter, and an app-level current-user contract that resolves the internal user UUID via `GET /api/v1/me`.

**Architecture:** Strangler / "transitional narrowing" (spec §3). Only the identity slice moves; every other feature stays on Supabase and is knowingly non-functional against real data until its own phase. `Supabase.initialize(...)` stays in startup. Work lands as three feature-sized PRs into `refactor/go-api-vps`, each leaving the branch buildable: **P2-4** (`core/network` client + deps + config), **P2-5** (Firebase Google end-to-end + current-user contract + consumer migration), **P2-6** (Apple end-to-end + operator/infra checklist + one emulator pass).

**Tech Stack:** Flutter, Riverpod 3 (codegen), Freezed 3 + json_serializable, Dio 5, `firebase_auth` 6.5.6, `firebase_core` 4.3.0 (already present), `google_sign_in` 7.2.0 (already present, v7 API), `sign_in_with_apple` 7.0.1, `crypto` (nonce hashing), mockito 5 (`@GenerateNiceMocks`, generated `*.mocks.dart`).

## Global Constraints

- **Backend is fixed and merged** (PR #466). Do not change Go code. The client integrates against the existing contract:
  - `GET /api/v1/me` (auth required) → `{"user":{"id":<uuid>,"status":<str>,"createdAt":<RFC3339 UTC>},"identity":{"issuer":<str>}}`.
  - Auth header: `Authorization: Bearer <Firebase ID token>`.
  - Error envelope on every non-2xx: `{"error":{"code":<str>,"message":<str>,"requestId":<str>}}`. Phase-2 codes: `unauthenticated` (401), `unavailable` (503), `internal` (500).
  - Request-ID header name: `X-Request-Id` (echoed back).
- **Base URL by build env** (spec §6.1): dev → **through Caddy on `:80`**, api is not host-published → Android emulator `http://10.0.2.2`, iOS sim `http://127.0.0.1`; staging `https://staging.peppercheck.dev`; production `https://peppercheck.dev`.
- **Dev cleartext HTTP is dev-flavor only.** Android `network_security_config` permitting cleartext to `10.0.2.2`/`localhost`; iOS ATS `NSAllowsLocalNetworking`. Staging/production are HTTPS with no exception.
- **Import boundaries:** `firebase_auth` only in `lib/features/auth/`; the authenticated-user path must not import `supabase_flutter`. CI-enforced (Task P2-5.11). (The "Dio construction only in `core/network`" check from spec §8 is **deferred** — `evidence`/`profile` legitimately still build Dio for R2 uploads until their own phase; enforcing it now would break CI on un-migrated code. Documented in Task P2-5.11.)
- **`core/network` never imports the Firebase SDK.** The bearer token arrives through an injected `IdTokenProvider` typedef; `features/auth` supplies the Firebase-backed implementation and overrides it at composition.
- **Naming convention (Option E, spec §4), applied to the code this plan touches only** (opportunistic, not a repo-wide rename): the auth feature adopts `domain/` · `application/` · `data/` · `ui/` (`*ViewModel`); DTOs are separate files mapping the HTTP contract, never DB rows; domain never imports DTOs.
- **Consumer migration is scoped to the compile-breaking set** — exactly the consumers of our own `currentUserProvider` / `authStateChangesProvider` whose types change (7 sites, §Task P2-5.8). Sites that read `Supabase.instance.client.auth.currentUser?.id` directly still compile (the SDK stays) and are left non-functional per narrowing (§3) — do **not** migrate them in Phase 2.
- **Per-PR verification = `flutter build apk --debug -t lib/main_dev.dart` + `flutter analyze` + `flutter test` only.** A single emulator end-to-end pass runs once at the end of Phase 2 (Task P2-6.7), per project convention (memory: consolidated emulator verification).
- **Language:** all committed content (code, comments, docs, test names, commit messages) in English.
- **Riverpod controller rule:** never name an `AsyncNotifier` method `update` (project rule) — use a domain-specific name.
- **Spacing:** `SizedBox` between sibling widgets, never per-item `Padding`; use `AppSizes` constants, never hardcoded pixels.

---

## File Structure

### P2-4 — `core/network` + config + deps

| Path | Responsibility |
|------|----------------|
| `peppercheck_flutter/pubspec.yaml` (modify) | add `firebase_auth: ^6.5.6` |
| `peppercheck_flutter/lib/app/config/app_environment.dart` (modify) | add per-env API base-URL resolution |
| `peppercheck_flutter/lib/core/network/api_exception.dart` (create) | `ApiException` — stable, provider-neutral client error |
| `peppercheck_flutter/lib/core/network/id_token_provider.dart` (create) | `IdTokenProvider` typedef + default (null) Riverpod provider |
| `peppercheck_flutter/lib/core/network/api_client.dart` (create) | `ApiClient` wrapping one Dio: interceptors (auth, request-id), timeouts, envelope→`ApiException` mapping |
| `peppercheck_flutter/lib/core/network/api_client_provider.dart` (create) | `apiClientProvider` — base URL from env, `IdTokenProvider` injected |
| `peppercheck_flutter/android/app/src/main/res/xml/network_security_config.xml` (create) | dev cleartext allowlist |
| `peppercheck_flutter/android/app/src/main/AndroidManifest.xml` (modify) | reference the network-security config |
| `peppercheck_flutter/ios/Runner/Info.plist` (modify) | ATS `NSAllowsLocalNetworking` |
| `peppercheck_flutter/test/core/network/api_client_test.dart` (create) | interceptor + error-mapping tests via a fake `HttpClientAdapter` |
| `peppercheck_flutter/test/app/config/app_environment_test.dart` (create) | base-URL resolution per env/platform |

### P2-5 — Firebase Google + current-user contract + consumer migration

| Path | Responsibility |
|------|----------------|
| `lib/features/auth/` (rename from `lib/features/authentication/`) | the auth feature, Option E layout |
| `lib/features/auth/domain/app_user.dart` (create) | `AppUser` — provider-neutral current user (`internalUserId`, `issuer`, `status`, `createdAt`) |
| `lib/features/auth/data/me_dto.dart` (create) | `MeResponse` DTO mirroring `/api/v1/me`; maps to `AppUser` |
| `lib/features/auth/data/auth_repository.dart` (rewrite from `authentication_repository.dart`) | Firebase adapter: `signInWithGoogle`, `signOut`, `idToken`; owns `firebase_auth` |
| `lib/features/auth/data/me_repository.dart` (create) | calls `GET /api/v1/me` via `ApiClient`, DTO→`AppUser` |
| `lib/features/auth/application/auth_state.dart` (rewrite from `data/auth_state_provider.dart`) | `authStateChanges` over `FirebaseAuth.authStateChanges()`; `currentAppUser` contract; Firebase-backed `idTokenProvider` override |
| `lib/features/auth/ui/sign_in_view_model.dart` (rewrite from `presentation/authentication_controller.dart`) | `SignInViewModel` |
| `lib/features/auth/ui/login_screen.dart` (move from `presentation/login_screen.dart`) | login UI |
| `lib/app/app_startup.dart` (modify) | override `idTokenProviderProvider` with the Firebase impl; keep `Supabase.initialize` |
| `lib/app/routing/app_router.dart` (modify) | redirect guard reads the new current-user contract; `/me`-failure limbo handling |
| 7 consumer files (modify) | see Task P2-5.8 |
| `lib/features/notification/application/fcm_service.dart` (modify) | listener off Supabase `onAuthStateChange` |
| `lib/features/notification/data/notification_repository.dart` (modify) | FCM token upsert gated off until Phase 3 |
| `scripts/check-flutter-imports.sh` (create) | import-boundary checks |
| `.github/workflows/ci-flutter.yml` (modify) | run the import check |
| `test/features/auth/**` (create/rewrite) | contract + repository + sign-out tests |
| `test/features/profile/presentation/username_edit_controller_test.dart` (modify) | override the new current-user provider |

### P2-6 — Apple + operator checklist + emulator pass

| Path | Responsibility |
|------|----------------|
| `peppercheck_flutter/pubspec.yaml` (modify) | add `sign_in_with_apple: ^7.0.1`, `crypto` |
| `lib/features/auth/data/apple_nonce.dart` (create) | secure nonce (random + SHA-256) |
| `lib/features/auth/data/auth_repository.dart` (modify) | `signInWithApple`; `account-exists-with-different-credential` link/cancel |
| `lib/features/auth/ui/login_screen.dart` (modify) | Apple sign-in button + link-consent prompt |
| `ios/Runner/*.entitlements` + Xcode project (modify) | Sign in with Apple capability per scheme |
| `docs/operations/phase2-auth-operator-checklist.md` (create) | per-env Firebase/Apple runbook (spec §7) |
| release-checklist Pending entries | operator actions per environment |
| `test/features/auth/apple_sign_in_test.dart` (create) | nonce; link-confirm and link-cancel paths |

---

## PR P2-4 — `core/network` shared HTTP client

### Task P2-4.1: Add `firebase_auth` dependency

**Files:**
- Modify: `peppercheck_flutter/pubspec.yaml`

- [ ] **Step 1: Add the dependency**

Run (from `peppercheck_flutter/`):

```bash
flutter pub add firebase_auth
```

Expected: resolves `firebase_auth 6.5.6` (compatible with `firebase_core: ^4.3.0`). Confirm `pubspec.yaml` now lists `firebase_auth: ^6.5.6`.

- [ ] **Step 2: Verify the project still resolves and builds**

Run:

```bash
flutter pub get
flutter analyze --no-fatal-infos 2>&1 | tail -5
```

Expected: no new analyzer errors. `firebase_auth` is not yet imported anywhere (that lands in P2-5); this task only pins it so `core/network`'s composition can compile later.

- [ ] **Step 3: Commit**

```bash
git add peppercheck_flutter/pubspec.yaml peppercheck_flutter/pubspec.lock
git commit -m "chore(flutter): add firebase_auth dependency"
```

---

### Task P2-4.2: Per-env API base-URL resolution

**Files:**
- Modify: `peppercheck_flutter/lib/app/config/app_environment.dart`
- Test: `peppercheck_flutter/test/app/config/app_environment_test.dart`

**Interfaces:**
- Produces: `String resolveApiBaseUrl(AppEnvironment env, {required bool isAndroid})` (top-level, pure) and `AppConfig.apiBaseUrl` (getter using `Platform.isAndroid`).

- [ ] **Step 1: Write the failing test**

Create `peppercheck_flutter/test/app/config/app_environment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/app/config/app_environment.dart';

void main() {
  group('resolveApiBaseUrl', () {
    test('dev on Android emulator uses 10.0.2.2 over cleartext', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.dev, isAndroid: true),
        'http://10.0.2.2',
      );
    });

    test('dev on iOS simulator uses 127.0.0.1 over cleartext', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.dev, isAndroid: false),
        'http://127.0.0.1',
      );
    });

    test('staging is HTTPS regardless of platform', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.staging, isAndroid: true),
        'https://staging.peppercheck.dev',
      );
      expect(
        resolveApiBaseUrl(AppEnvironment.staging, isAndroid: false),
        'https://staging.peppercheck.dev',
      );
    });

    test('production is HTTPS regardless of platform', () {
      expect(
        resolveApiBaseUrl(AppEnvironment.production, isAndroid: true),
        'https://peppercheck.dev',
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app/config/app_environment_test.dart`
Expected: FAIL — `resolveApiBaseUrl` is undefined.

- [ ] **Step 3: Implement the resolver**

In `lib/app/config/app_environment.dart`, add `import 'dart:io';` at the top and append:

```dart
/// Resolves the Go API base URL for [env]. Dev goes through Caddy on :80
/// (the api is not host-published), so the host differs by emulator:
/// Android uses 10.0.2.2, the iOS simulator uses 127.0.0.1. Cleartext HTTP is
/// permitted for dev only (see the Android network-security config and iOS ATS
/// exception). Staging/production are HTTPS with no exception.
String resolveApiBaseUrl(AppEnvironment env, {required bool isAndroid}) {
  return switch (env) {
    AppEnvironment.dev =>
      isAndroid ? 'http://10.0.2.2' : 'http://127.0.0.1',
    AppEnvironment.staging => 'https://staging.peppercheck.dev',
    AppEnvironment.production => 'https://peppercheck.dev',
  };
}

extension AppConfigApiBaseUrl on AppConfig {
  /// The Go API base URL for this config's environment on the current platform.
  String get apiBaseUrl =>
      resolveApiBaseUrl(environment, isAndroid: Platform.isAndroid);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app/config/app_environment_test.dart`
Expected: PASS (all 4).

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/app/config/app_environment.dart peppercheck_flutter/test/app/config/app_environment_test.dart
git commit -m "feat(flutter): resolve Go API base URL per environment"
```

---

### Task P2-4.3: `ApiException`

**Files:**
- Create: `peppercheck_flutter/lib/core/network/api_exception.dart`
- Test: covered by `api_client_test.dart` (Task P2-4.5); a focused constructor test here.

**Interfaces:**
- Produces: `class ApiException implements Exception { final String code; final String message; final String? requestId; final int? statusCode; }` with named constructor `ApiException.network()` (code `network`) and `ApiException.timeout()` (code `timeout`).

- [ ] **Step 1: Write the failing test**

Create `peppercheck_flutter/test/core/network/api_exception_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';

void main() {
  test('carries stable code, message, requestId, statusCode', () {
    const e = ApiException(
      code: 'unauthenticated',
      message: 'no token',
      requestId: 'req-1',
      statusCode: 401,
    );
    expect(e.code, 'unauthenticated');
    expect(e.statusCode, 401);
    expect(e.requestId, 'req-1');
    expect(e.toString(), contains('unauthenticated'));
  });

  test('network and timeout named constructors set their codes', () {
    expect(const ApiException.network().code, 'network');
    expect(const ApiException.timeout().code, 'timeout');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/network/api_exception_test.dart`
Expected: FAIL — `ApiException` undefined.

- [ ] **Step 3: Implement**

Create `peppercheck_flutter/lib/core/network/api_exception.dart`:

```dart
/// A stable, provider-neutral error surfaced by [ApiClient]. Dio and Firebase
/// exceptions are mapped to this at the network boundary and never reach the
/// domain or UI layers directly.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
  });

  /// A transport failure (no HTTP response received).
  const ApiException.network()
      : code = 'network',
        message = 'network error',
        requestId = null,
        statusCode = null;

  /// A connect/receive/send timeout.
  const ApiException.timeout()
      : code = 'timeout',
        message = 'request timed out',
        requestId = null,
        statusCode = null;

  /// Stable machine-readable code (server envelope `error.code`, or
  /// `network`/`timeout`/`unknown` for client-side failures).
  final String code;

  /// Human-readable detail. Not for control flow — branch on [code].
  final String message;

  /// Correlates with the server log line (`X-Request-Id`), when available.
  final String? requestId;

  /// HTTP status when a response was received; null for transport failures.
  final int? statusCode;

  @override
  String toString() =>
      'ApiException(code: $code, status: $statusCode, requestId: $requestId, message: $message)';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/network/api_exception_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/core/network/api_exception.dart peppercheck_flutter/test/core/network/api_exception_test.dart
git commit -m "feat(flutter): add ApiException for the network boundary"
```

---

### Task P2-4.4: `IdTokenProvider` typedef + default provider

**Files:**
- Create: `peppercheck_flutter/lib/core/network/id_token_provider.dart`

**Interfaces:**
- Produces:
  - `typedef IdTokenProvider = Future<String?> Function({required bool forceRefresh});`
  - `@riverpod IdTokenProvider idTokenProvider(Ref ref)` — default returns null (overridden by `features/auth` at composition, P2-5).

- [ ] **Step 1: Implement (no unit test — trivial default; exercised by `apiClientProvider` and the auth override)**

Create `peppercheck_flutter/lib/core/network/id_token_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'id_token_provider.g.dart';

/// Supplies the current bearer token for authenticated API calls. Injected so
/// `core/network` never imports the Firebase SDK; `features/auth` provides the
/// Firebase-backed implementation and overrides [idTokenProvider] at app
/// composition (Phase 2 P2-5).
typedef IdTokenProvider = Future<String?> Function({required bool forceRefresh});

/// Default: no token. Replaced by the Firebase implementation at composition.
@riverpod
IdTokenProvider idTokenProvider(Ref ref) {
  return ({required bool forceRefresh}) async => null;
}
```

- [ ] **Step 2: Generate Riverpod code**

Run: `dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5`
Expected: generates `id_token_provider.g.dart`, no errors.

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze --no-fatal-infos lib/core/network/ 2>&1 | tail -5`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add peppercheck_flutter/lib/core/network/id_token_provider.dart peppercheck_flutter/lib/core/network/id_token_provider.g.dart
git commit -m "feat(flutter): add IdTokenProvider seam for the API client"
```

---

### Task P2-4.5: `ApiClient` — interceptors, timeouts, error mapping

**Files:**
- Create: `peppercheck_flutter/lib/core/network/api_client.dart`
- Test: `peppercheck_flutter/test/core/network/api_client_test.dart`

**Interfaces:**
- Consumes: `IdTokenProvider` (P2-4.4), `ApiException` (P2-4.3).
- Produces:
  - `class ApiClient` constructed `ApiClient({required String baseUrl, required IdTokenProvider idTokenProvider, Dio? dio})`.
  - `Future<Map<String, dynamic>> getJson(String path, {bool authenticated = true})`.
  - Later features add methods as needed; Phase 2 needs only `getJson`.

- [ ] **Step 1: Write the failing tests**

Create `peppercheck_flutter/test/core/network/api_client_test.dart`. This uses a fake `HttpClientAdapter` (no extra dependency) so we assert on outgoing headers and control the response:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';

/// Records the last request and returns a scripted response. `handler` lets a
/// test vary the response by attempt (for the 401-retry case).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options, int attempt) handler;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options, requests.length);
  }
}

ResponseBody _json(int status, Map<String, dynamic> body,
    {Map<String, List<String>>? headers}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...?headers,
    },
  );
}

ApiClient _client(_FakeAdapter adapter,
    {Future<String?> Function({required bool forceRefresh})? tokens}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter;
  return ApiClient(
    baseUrl: 'http://test.local',
    idTokenProvider: tokens ?? ({required bool forceRefresh}) async => 'tok-1',
    dio: dio,
  );
}

void main() {
  test('attaches Authorization bearer on authenticated GET', () async {
    final adapter = _FakeAdapter((o, _) => _json(200, {'ok': true}));
    final client = _client(adapter);

    await client.getJson('/api/v1/me');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-1');
  });

  test('attaches an X-Request-Id header', () async {
    final adapter = _FakeAdapter((o, _) => _json(200, {'ok': true}));
    final client = _client(adapter);

    await client.getJson('/api/v1/me');

    final reqId = adapter.requests.single.headers['X-Request-Id'];
    expect(reqId, isNotNull);
    expect((reqId as String).isNotEmpty, isTrue);
  });

  test('maps the server error envelope to ApiException', () async {
    final adapter = _FakeAdapter((o, _) => _json(401, {
          'error': {
            'code': 'unauthenticated',
            'message': 'no token',
            'requestId': 'req-9',
          }
        }));
    final client = _client(adapter);

    expect(
      () => client.getJson('/api/v1/me'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'unauthenticated')
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.requestId, 'requestId', 'req-9')),
    );
  });

  test('on 401 refreshes the token and retries the GET exactly once', () async {
    var forced = <bool>[];
    final adapter = _FakeAdapter((o, attempt) {
      if (attempt == 1) {
        return _json(401, {
          'error': {'code': 'unauthenticated', 'message': 'expired', 'requestId': 'r'}
        });
      }
      return _json(200, {'user': {'id': 'u1'}});
    });
    final client = _client(adapter, tokens: ({required bool forceRefresh}) async {
      forced.add(forceRefresh);
      return forceRefresh ? 'tok-2' : 'tok-1';
    });

    final body = await client.getJson('/api/v1/me');

    expect(adapter.requests.length, 2, reason: 'one retry');
    expect(adapter.requests[0].headers['Authorization'], 'Bearer tok-1');
    expect(adapter.requests[1].headers['Authorization'], 'Bearer tok-2');
    expect(forced, [false, true]);
    expect(body['user']['id'], 'u1');
  });

  test('does not retry a second time — a 401 after refresh throws', () async {
    final adapter = _FakeAdapter((o, _) => _json(401, {
          'error': {'code': 'unauthenticated', 'message': 'x', 'requestId': 'r'}
        }));
    final client = _client(adapter);

    await expectLater(
        () => client.getJson('/api/v1/me'), throwsA(isA<ApiException>()));
    expect(adapter.requests.length, 2, reason: 'initial + exactly one retry');
  });

  test('maps a connection timeout to ApiException.timeout', () async {
    final adapter = _FakeAdapter((o, _) =>
        throw DioException.connectionTimeout(
            timeout: const Duration(seconds: 1), requestOptions: o));
    final client = _client(adapter);

    expect(
      () => client.getJson('/api/v1/me'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/network/api_client_test.dart`
Expected: FAIL — `ApiClient` / `getJson` undefined.

- [ ] **Step 3: Implement `ApiClient`**

Create `peppercheck_flutter/lib/core/network/api_client.dart`:

```dart
import 'dart:math';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'id_token_provider.dart';

/// The single configured HTTP client for the Go API. Features must not build
/// their own Dio. Responsibilities: base URL by build env, bearer-token
/// injection (via [IdTokenProvider], not a direct Firebase call), request-id
/// propagation, bounded timeouts, and mapping the server error envelope to a
/// stable [ApiException]. Non-idempotent mutations are never auto-retried.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required IdTokenProvider idTokenProvider,
    Dio? dio,
  })  : _idTokenProvider = idTokenProvider,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              // We handle status validation ourselves so the interceptor can
              // observe 401s; never throw on non-2xx here.
              validateStatus: (_) => true,
            )) {
    if (dio != null) {
      _dio.options
        ..baseUrl = baseUrl
        ..connectTimeout ??= const Duration(seconds: 10)
        ..receiveTimeout ??= const Duration(seconds: 20)
        ..sendTimeout ??= const Duration(seconds: 20)
        ..validateStatus = (_) => true;
    }
  }

  final Dio _dio;
  final IdTokenProvider _idTokenProvider;

  static const _requestIdHeader = 'X-Request-Id';
  final _rng = Random();

  String _newRequestId() {
    // 16 hex chars is enough to correlate a client call with a server log line.
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// GET [path] and decode a JSON object. On 401 for this idempotent GET, the
  /// token is force-refreshed and the request retried exactly once.
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = true,
  }) async {
    Response<dynamic> res;
    try {
      res = await _send(path, authenticated: authenticated, forceRefresh: false);
      if (res.statusCode == 401 && authenticated) {
        res = await _send(path, authenticated: authenticated, forceRefresh: true);
      }
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
    if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    }
    throw _mapErrorResponse(res);
  }

  Future<Response<dynamic>> _send(
    String path, {
    required bool authenticated,
    required bool forceRefresh,
  }) async {
    final headers = <String, dynamic>{_requestIdHeader: _newRequestId()};
    if (authenticated) {
      final token = await _idTokenProvider(forceRefresh: forceRefresh);
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return _dio.get<dynamic>(path, options: Options(headers: headers));
  }

  ApiException _mapErrorResponse(Response<dynamic> res) {
    final status = res.statusCode;
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: (err['code'] as String?) ?? 'unknown',
        message: (err['message'] as String?) ?? 'request failed',
        requestId: err['requestId'] as String?,
        statusCode: status,
      );
    }
    return ApiException(
      code: 'unknown',
      message: 'request failed',
      statusCode: status,
    );
  }

  ApiException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException.timeout();
      case DioExceptionType.connectionError:
        return const ApiException.network();
      case DioExceptionType.badResponse:
        if (e.response != null) return _mapErrorResponse(e.response!);
        return const ApiException.network();
      default:
        return const ApiException.network();
    }
  }
}
```

> Design note: we validate status ourselves (`validateStatus: (_) => true`) and drive the single 401-retry in `getJson`, rather than an `onError` interceptor, so the "exactly once, idempotent GET only" rule is explicit and easy to test. Future non-GET methods will not call the retry branch.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/network/api_client_test.dart`
Expected: PASS (all 6).

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/core/network/api_client.dart peppercheck_flutter/test/core/network/api_client_test.dart
git commit -m "feat(flutter): add shared ApiClient with auth/request-id/error mapping"
```

---

### Task P2-4.6: `apiClientProvider`

**Files:**
- Create: `peppercheck_flutter/lib/core/network/api_client_provider.dart`

**Interfaces:**
- Consumes: `appEnvironmentProvider` (existing, `lib/app/config/app_environment.dart`), `idTokenProvider` (P2-4.4), `resolveApiBaseUrl` (P2-4.2).
- Produces: `@riverpod ApiClient apiClient(Ref ref)`.

- [ ] **Step 1: Implement**

Create `peppercheck_flutter/lib/core/network/api_client_provider.dart`:

```dart
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/config/app_environment.dart';
import 'api_client.dart';
import 'id_token_provider.dart';

part 'api_client_provider.g.dart';

/// The app-wide [ApiClient]. Base URL comes from the build environment; the
/// bearer token comes from [idTokenProvider] (overridden by `features/auth`).
@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final env = ref.watch(appEnvironmentProvider);
  final baseUrl = resolveApiBaseUrl(env, isAndroid: Platform.isAndroid);
  final tokens = ref.watch(idTokenProvider);
  return ApiClient(baseUrl: baseUrl, idTokenProvider: tokens);
}
```

- [ ] **Step 2: Generate Riverpod code**

Run: `dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5`
Expected: generates `api_client_provider.g.dart`, no errors.

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze --no-fatal-infos lib/core/network/ 2>&1 | tail -5`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add peppercheck_flutter/lib/core/network/api_client_provider.dart peppercheck_flutter/lib/core/network/api_client_provider.g.dart
git commit -m "feat(flutter): wire apiClientProvider from env + id-token seam"
```

---

### Task P2-4.7: Dev cleartext — Android network-security config + iOS ATS

**Files:**
- Create: `peppercheck_flutter/android/app/src/main/res/xml/network_security_config.xml`
- Modify: `peppercheck_flutter/android/app/src/main/AndroidManifest.xml`
- Modify: `peppercheck_flutter/ios/Runner/Info.plist`

> No unit test (native config). Verified by the flavored debug build in Step 4.

- [ ] **Step 1: Create the Android network-security config**

Create `peppercheck_flutter/android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!--
  Dev-only cleartext allowlist: the dev flavor talks to the Go API through
  Caddy on the loopback host (10.0.2.2 for the Android emulator). All other
  traffic remains HTTPS-only (cleartextTrafficPermitted defaults to false on
  API 28+). Staging/production build against HTTPS endpoints and never hit
  this allowlist.
-->
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">10.0.2.2</domain>
        <domain includeSubdomains="false">localhost</domain>
        <domain includeSubdomains="false">127.0.0.1</domain>
    </domain-config>
</network-security-config>
```

- [ ] **Step 2: Reference it from the manifest**

In `peppercheck_flutter/android/app/src/main/AndroidManifest.xml`, add `android:networkSecurityConfig` to the `<application>` tag (keep existing attributes):

```xml
<application
    android:label="..."
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

> This config is applied to all flavors, but it only *permits* cleartext to the loopback hosts; staging/production URLs are public HTTPS domains and are unaffected. A stricter per-flavor manifest is unnecessary because the allowlist is loopback-only.

- [ ] **Step 3: Add the iOS ATS local-networking exception**

In `peppercheck_flutter/ios/Runner/Info.plist`, add inside the top-level `<dict>`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <!-- Dev-only: the iOS simulator reaches the Go API via Caddy on
         127.0.0.1. NSAllowsLocalNetworking permits cleartext to
         loopback/.local hosts without opening arbitrary loads. -->
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

- [ ] **Step 4: Verify the flavored debug build**

Run (from `peppercheck_flutter/`):

```bash
flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/android/app/src/main/res/xml/network_security_config.xml peppercheck_flutter/android/app/src/main/AndroidManifest.xml peppercheck_flutter/ios/Runner/Info.plist
git commit -m "feat(flutter): allow dev-only cleartext to the loopback Go API"
```

---

## PR P2-5 — Firebase Google end-to-end + current-user contract

> After this PR the app signs in with **Google via Firebase**, resolves the internal user through `GET /api/v1/me`, and signs out — with no Supabase on the auth path. Data-heavy features stay non-functional (narrowing, §3).

### Task P2-5.1: Rename `authentication` → `auth` and adopt Option E layout

**Files:**
- Rename: `lib/features/authentication/` → `lib/features/auth/`, then restructure folders.

- [ ] **Step 1: Move the feature directory with git**

Run (from repo root):

```bash
git mv peppercheck_flutter/lib/features/authentication peppercheck_flutter/lib/features/auth
```

- [ ] **Step 2: Create Option E subfolders and move files into them**

Run:

```bash
cd peppercheck_flutter/lib/features/auth
mkdir -p domain application
git mv presentation ui
git mv data/auth_state_provider.dart application/auth_state.dart
git mv data/auth_state_provider.g.dart application/auth_state.g.dart
git mv data/authentication_repository.dart data/auth_repository.dart
git mv data/authentication_repository.g.dart data/auth_repository.g.dart
git mv ui/authentication_controller.dart ui/sign_in_view_model.dart
git mv ui/authentication_controller.g.dart ui/sign_in_view_model.g.dart
```

> The file *contents* (class names, providers) are rewritten in later tasks (P2-5.4–P2-5.6). This step only relocates and renames files so imports move as a mechanical unit. The `.g.dart` files are regenerated after the rewrites; moving them now keeps the tree consistent for the interim build.

- [ ] **Step 3: Fix import paths and part directives across the repo**

Update every `package:peppercheck_flutter/features/authentication/...` import to `.../auth/...`, and the moved files' own `part` directives / relative imports. Find them:

```bash
cd /Users/makoto/projects/peppercheck
grep -rl "features/authentication" peppercheck_flutter/lib peppercheck_flutter/test
```

Update each hit. Known referencing files include `lib/app/routing/app_router.dart`, `lib/features/auth/ui/login_screen.dart`, and any test under `test/features/authentication/` (also `git mv` that test dir to `test/features/auth/`).

> Do not yet rename the *classes* (`AuthenticationController`, `authenticationRepositoryProvider`) — that happens in P2-5.4/P2-5.6 where the code is rewritten. This step keeps them compiling under the new paths.

- [ ] **Step 4: Regenerate and verify analyze**

Run (from `peppercheck_flutter/`):

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter analyze --no-fatal-infos 2>&1 | tail -10
```

Expected: no errors — a pure relocation.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(flutter): rename authentication feature to auth with Option E layout"
```

---

### Task P2-5.2: `AppUser` domain model

**Files:**
- Create: `lib/features/auth/domain/app_user.dart`
- Test: `test/features/auth/domain/app_user_test.dart`

**Interfaces:**
- Produces: `class AppUser` (Freezed) with `String internalUserId`, `String issuer`, `String status`, `DateTime createdAt`.

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/domain/app_user_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';

void main() {
  test('AppUser holds the internal identity fields', () {
    final u = AppUser(
      internalUserId: 'uuid-1',
      issuer: 'https://securetoken.google.com/pc-dev',
      status: 'active',
      createdAt: DateTime.utc(2026, 7, 25),
    );
    expect(u.internalUserId, 'uuid-1');
    expect(u.issuer, contains('securetoken'));
    expect(u.status, 'active');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/domain/app_user_test.dart`
Expected: FAIL — `AppUser` undefined.

- [ ] **Step 3: Implement**

Create `lib/features/auth/domain/app_user.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// The app-level current user, provider-neutral. This is the ONLY user type
/// features read; it exposes the PepperCheck-internal UUID (Phase 5 wires
/// RevenueCat identify to [internalUserId]). It carries no profile — profile
/// lands in Phase 3. Domain type: it imports no DTO and no Firebase type.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String internalUserId,
    required String issuer,
    required String status,
    required DateTime createdAt,
  }) = _AppUser;
}
```

- [ ] **Step 4: Generate Freezed code and run the test**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/domain/app_user_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/features/auth/domain/app_user.dart peppercheck_flutter/lib/features/auth/domain/app_user.freezed.dart peppercheck_flutter/test/features/auth/domain/app_user_test.dart
git commit -m "feat(flutter): add AppUser current-user domain model"
```

---

### Task P2-5.3: `MeResponse` DTO + mapping

**Files:**
- Create: `lib/features/auth/data/me_dto.dart`
- Test: `test/features/auth/data/me_dto_test.dart`

**Interfaces:**
- Consumes: `AppUser` (P2-5.2).
- Produces: `MeResponse` (Freezed + json) with nested `MeUser {id,status,createdAt}` and `MeIdentity {issuer}`; `AppUser toDomain()`.

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/data/me_dto_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/auth/data/me_dto.dart';

void main() {
  test('parses the /api/v1/me envelope and maps to AppUser', () {
    final json = {
      'user': {
        'id': 'uuid-9',
        'status': 'active',
        'createdAt': '2026-07-25T01:02:03Z',
      },
      'identity': {'issuer': 'https://securetoken.google.com/pc-dev'},
    };

    final dto = MeResponse.fromJson(json);
    final user = dto.toDomain();

    expect(user.internalUserId, 'uuid-9');
    expect(user.status, 'active');
    expect(user.issuer, 'https://securetoken.google.com/pc-dev');
    expect(user.createdAt, DateTime.utc(2026, 7, 25, 1, 2, 3));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/data/me_dto_test.dart`
Expected: FAIL — `MeResponse` undefined.

- [ ] **Step 3: Implement**

Create `lib/features/auth/data/me_dto.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/app_user.dart';

part 'me_dto.freezed.dart';
part 'me_dto.g.dart';

/// Mirrors the `GET /api/v1/me` response envelope (HTTP contract, not a DB row).
/// The repository maps this to [AppUser]; domain never imports this DTO.
@freezed
abstract class MeResponse with _$MeResponse {
  const MeResponse._();

  const factory MeResponse({
    required MeUser user,
    required MeIdentity identity,
  }) = _MeResponse;

  factory MeResponse.fromJson(Map<String, dynamic> json) =>
      _$MeResponseFromJson(json);

  AppUser toDomain() => AppUser(
        internalUserId: user.id,
        issuer: identity.issuer,
        status: user.status,
        createdAt: DateTime.parse(user.createdAt),
      );
}

@freezed
abstract class MeUser with _$MeUser {
  const factory MeUser({
    required String id,
    required String status,
    required String createdAt,
  }) = _MeUser;

  factory MeUser.fromJson(Map<String, dynamic> json) => _$MeUserFromJson(json);
}

@freezed
abstract class MeIdentity with _$MeIdentity {
  const factory MeIdentity({required String issuer}) = _MeIdentity;

  factory MeIdentity.fromJson(Map<String, dynamic> json) =>
      _$MeIdentityFromJson(json);
}
```

- [ ] **Step 4: Generate and run the test**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/data/me_dto_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/features/auth/data/me_dto.dart peppercheck_flutter/lib/features/auth/data/me_dto.freezed.dart peppercheck_flutter/lib/features/auth/data/me_dto.g.dart peppercheck_flutter/test/features/auth/data/me_dto_test.dart
git commit -m "feat(flutter): add MeResponse DTO mapping to AppUser"
```

---

### Task P2-5.4: Firebase auth repository (Google + sign-out + id token)

**Files:**
- Rewrite: `lib/features/auth/data/auth_repository.dart`
- Test: `test/features/auth/data/auth_repository_test.dart`

**Interfaces:**
- Produces:
  - `class AuthRepository` constructed with `FirebaseAuth`, `GoogleSignIn`, `Logger`.
  - `Future<void> signInWithGoogle()` — Google → Firebase credential.
  - `Future<void> signOut()` — independent, idempotent legs.
  - `Future<String?> idToken({required bool forceRefresh})` — for the `IdTokenProvider` seam.
  - `@Riverpod(keepAlive: true) AuthRepository authRepository(Ref ref)`.

> `firebase_auth` is imported here (allowed — this is `features/auth`). We inject `FirebaseAuth`/`GoogleSignIn` so tests use mockito mocks. `GoogleSignIn.instance` is already initialized in `app_startup` (`GoogleSignIn.instance.initialize()`); the repository takes the instance.

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/data/auth_repository_test.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';

import 'auth_repository_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<GoogleSignIn>(),
  MockSpec<GoogleSignInAccount>(),
  MockSpec<GoogleSignInAuthentication>(),
  MockSpec<Logger>(),
])
void main() {
  late MockFirebaseAuth auth;
  late MockGoogleSignIn google;
  late AuthRepository repo;

  setUp(() {
    auth = MockFirebaseAuth();
    google = MockGoogleSignIn();
    repo = AuthRepository(
      firebaseAuth: auth,
      googleSignIn: google,
      logger: MockLogger(),
    );
  });

  test('signInWithGoogle exchanges the Google idToken for a Firebase sign-in',
      () async {
    final account = MockGoogleSignInAccount();
    final gAuth = MockGoogleSignInAuthentication();
    when(gAuth.idToken).thenReturn('google-id-token');
    when(account.authentication).thenReturn(gAuth);
    when(google.authenticate()).thenAnswer((_) async => account);
    when(auth.signInWithCredential(any))
        .thenAnswer((_) async => MockUserCredential());

    await repo.signInWithGoogle();

    final captured =
        verify(auth.signInWithCredential(captureany)).captured.single
            as AuthCredential;
    expect(captured.providerId, 'google.com');
  });

  test('signOut runs each leg independently even if one throws', () async {
    when(google.signOut()).thenThrow(Exception('google boom'));
    when(auth.signOut()).thenAnswer((_) async {});

    await repo.signOut(); // must not throw

    verify(auth.signOut()).called(1);
    verify(google.signOut()).called(1);
  });

  test('idToken delegates to the current Firebase user with forceRefresh',
      () async {
    final user = MockUser();
    when(user.getIdToken(true)).thenAnswer((_) async => 'tok');
    when(auth.currentUser).thenReturn(user);

    final t = await repo.idToken(forceRefresh: true);

    expect(t, 'tok');
    verify(user.getIdToken(true)).called(1);
  });

  test('idToken returns null when signed out', () async {
    when(auth.currentUser).thenReturn(null);
    expect(await repo.idToken(forceRefresh: false), isNull);
  });
}
```

Add `MockSpec<UserCredential>()` and `MockSpec<User>()` to the `@GenerateNiceMocks` list.

- [ ] **Step 2: Generate mocks, run to verify failure**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/data/auth_repository_test.dart
```

Expected: FAIL — `AuthRepository` undefined / signature mismatch.

- [ ] **Step 3: Implement the repository**

Rewrite `lib/features/auth/data/auth_repository.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/providers/logger_provider.dart';

part 'auth_repository.g.dart';

/// Firebase authentication adapter. This is the ONLY place that imports
/// `firebase_auth`. Google sign-in exchanges the Google ID token for a Firebase
/// credential; sign-out runs each leg independently and idempotently.
class AuthRepository {
  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required Logger logger,
  })  : _auth = firebaseAuth,
        _google = googleSignIn,
        _logger = logger;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  final Logger _logger;

  Future<void> signInWithGoogle() async {
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in returned no ID token');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
  }

  /// Signs out of every provider. Each leg is attempted independently so one
  /// failure does not abandon the others (replaces the old `Future.wait`,
  /// which lost partial failures). Phase 3 adds FCM unregister; Phase 5 adds
  /// RevenueCat logout — each as its own guarded leg here.
  Future<void> signOut() async {
    await _guard('google', () => _google.signOut());
    await _guard('firebase', () => _auth.signOut());
  }

  /// The current Firebase ID token, or null when signed out. Backs the
  /// `IdTokenProvider` seam consumed by `core/network`.
  Future<String?> idToken({required bool forceRefresh}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  Future<void> _guard(String leg, Future<void> Function() op) async {
    try {
      await op();
    } catch (e, st) {
      _logger.w('sign-out leg "$leg" failed', error: e, stackTrace: st);
    }
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    googleSignIn: GoogleSignIn.instance,
    logger: ref.watch(loggerProvider),
  );
}
```

> Verify the `loggerProvider` import path — the old repository imported it; reuse the exact path it used (`grep -rn "loggerProvider" lib/common` if unsure).

- [ ] **Step 4: Regenerate and run the test**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/data/auth_repository_test.dart
```

Expected: PASS (all 4).

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/features/auth/data/auth_repository.dart peppercheck_flutter/lib/features/auth/data/auth_repository.g.dart peppercheck_flutter/test/features/auth/data/auth_repository_test.dart peppercheck_flutter/test/features/auth/data/auth_repository_test.mocks.dart
git commit -m "feat(flutter): Firebase Google sign-in adapter with idempotent sign-out"
```

---

### Task P2-5.5: `me` repository (calls `/api/v1/me`)

**Files:**
- Create: `lib/features/auth/data/me_repository.dart`
- Test: `test/features/auth/data/me_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient` (P2-4.5), `MeResponse` (P2-5.3), `AppUser`.
- Produces: `class MeRepository { Future<AppUser> fetchMe(); }` + `@riverpod MeRepository meRepository(Ref ref)` (reads `apiClientProvider`).

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/data/me_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/features/auth/data/me_repository.dart';

import 'me_repository_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ApiClient>()])
void main() {
  test('fetchMe maps the /api/v1/me envelope to AppUser', () async {
    final api = MockApiClient();
    when(api.getJson('/api/v1/me')).thenAnswer((_) async => {
          'user': {
            'id': 'uuid-3',
            'status': 'active',
            'createdAt': '2026-07-25T00:00:00Z',
          },
          'identity': {'issuer': 'https://securetoken.google.com/pc-dev'},
        });

    final user = await MeRepository(api).fetchMe();

    expect(user.internalUserId, 'uuid-3');
    expect(user.issuer, contains('pc-dev'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/data/me_repository_test.dart
```

Expected: FAIL — `MeRepository` undefined.

- [ ] **Step 3: Implement**

Create `lib/features/auth/data/me_repository.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_client.dart';
import '../domain/app_user.dart';
import 'me_dto.dart';

part 'me_repository.g.dart';

/// Resolves the internal user via `GET /api/v1/me` and maps the DTO to domain.
class MeRepository {
  MeRepository(this._api);

  final ApiClient _api;

  Future<AppUser> fetchMe() async {
    final json = await _api.getJson('/api/v1/me');
    return MeResponse.fromJson(json).toDomain();
  }
}

@riverpod
MeRepository meRepository(Ref ref) => MeRepository(ref.watch(apiClientProvider));
```

- [ ] **Step 4: Regenerate and run the test**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/data/me_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/features/auth/data/me_repository.dart peppercheck_flutter/lib/features/auth/data/me_repository.g.dart peppercheck_flutter/test/features/auth/data/me_repository_test.dart peppercheck_flutter/test/features/auth/data/me_repository_test.mocks.dart
git commit -m "feat(flutter): add MeRepository resolving the internal user"
```

---

### Task P2-5.6: Auth-state + current-user contract + Firebase id-token override

**Files:**
- Rewrite: `lib/features/auth/application/auth_state.dart`
- Test: `test/features/auth/application/current_app_user_test.dart`

**Interfaces:**
- Consumes: `authRepository` (P2-5.4), `meRepository` (P2-5.5), `AppUser`, `IdTokenProvider` (P2-4.4).
- Produces:
  - `@Riverpod(keepAlive: true) Stream<User?> authStateChanges(Ref ref)` — `FirebaseAuth.instance.authStateChanges()` (Firebase `User?`, kept **inside** `features/auth` only).
  - `@Riverpod(keepAlive: true) Future<AppUser?> currentAppUser(Ref ref)` — when Firebase-authenticated, resolves `/api/v1/me`; null when signed out.
  - `IdTokenProvider firebaseIdTokenProvider(Ref ref)` — returns `authRepository.idToken`, used to override `idTokenProvider` at composition.

> Note the type change: the old `currentUserProvider` returned a Supabase `User?`. It is **replaced** by `currentAppUser` (an `AppUser?`). Consumers migrate in P2-5.8. The Firebase `User?` type never leaves `features/auth`.

- [ ] **Step 1: Write the failing test**

Create `test/features/auth/application/current_app_user_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/data/me_repository.dart';
import 'package:peppercheck_flutter/features/auth/domain/app_user.dart';
import 'package:riverpod/riverpod.dart';

import 'current_app_user_test.mocks.dart';

@GenerateNiceMocks([MockSpec<MeRepository>()])
void main() {
  test('currentAppUser resolves the internal user when authenticated',
      () async {
    final me = MockMeRepository();
    when(me.fetchMe()).thenAnswer((_) async => AppUser(
          internalUserId: 'uuid-1',
          issuer: 'iss',
          status: 'active',
          createdAt: DateTime.utc(2026),
        ));

    final container = ProviderContainer(overrides: [
      meRepositoryProvider.overrideWithValue(me),
      // authStateChanges overridden to a signed-in Firebase user stand-in:
      authStateChangesProvider.overrideWith((ref) => Stream.value(_signedIn)),
    ]);
    addTearDown(container.dispose);

    final user = await container.read(currentAppUserProvider.future);
    expect(user?.internalUserId, 'uuid-1');
  });
}
```

> If constructing a fake Firebase `User` is awkward, override `currentAppUser`'s dependency on the auth-state boolean instead (see implementation note). Keep the test asserting: authenticated → resolves `/me`; signed out → null. `_signedIn` can be a minimal stub or the test can override an intermediate `isFirebaseAuthenticatedProvider` boolean — pick whichever the implementation exposes and keep both cases (`true`→resolves, `false`→null) tested.

- [ ] **Step 2: Implement `auth_state.dart`**

Rewrite `lib/features/auth/application/auth_state.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/id_token_provider.dart';
import '../data/auth_repository.dart';
import '../data/me_repository.dart';
import '../domain/app_user.dart';

part 'auth_state.g.dart';

/// Firebase auth-state stream. The Firebase `User?` type is confined to this
/// feature — other features read [currentAppUser] instead.
@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(Ref ref) =>
    FirebaseAuth.instance.authStateChanges();

/// True while a Firebase user is present. Extracted so tests and the router can
/// branch without touching the Firebase `User` type.
@Riverpod(keepAlive: true)
bool isFirebaseAuthenticated(Ref ref) =>
    ref.watch(authStateChangesProvider).value != null;

/// The app-level current user. When Firebase-authenticated, resolves the
/// internal user via `GET /api/v1/me`; null when signed out. This is where the
/// internal UUID is exposed to the rest of the app (Phase 5 RevenueCat wiring).
@Riverpod(keepAlive: true)
Future<AppUser?> currentAppUser(Ref ref) async {
  if (!ref.watch(isFirebaseAuthenticatedProvider)) return null;
  return ref.watch(meRepositoryProvider).fetchMe();
}

/// Firebase-backed [IdTokenProvider]. Overrides the default (null) provider at
/// composition so `core/network` gets real bearer tokens without importing the
/// Firebase SDK.
IdTokenProvider firebaseIdTokenProvider(Ref ref) {
  final repo = ref.watch(authRepositoryProvider);
  return ({required bool forceRefresh}) => repo.idToken(forceRefresh: forceRefresh);
}
```

- [ ] **Step 3: Generate, run the test**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/application/current_app_user_test.dart
```

Expected: PASS (adjust the test's override seam to `isFirebaseAuthenticatedProvider` if the Firebase-`User` stub is impractical: override `isFirebaseAuthenticatedProvider` → `true`/`false` and assert resolves/null).

- [ ] **Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/auth/application/auth_state.dart peppercheck_flutter/lib/features/auth/application/auth_state.g.dart peppercheck_flutter/test/features/auth/application/
git commit -m "feat(flutter): Firebase auth-state and internal current-user contract"
```

---

### Task P2-5.7: `SignInViewModel` + login screen

**Files:**
- Rewrite: `lib/features/auth/ui/sign_in_view_model.dart`
- Modify: `lib/features/auth/ui/login_screen.dart`

**Interfaces:**
- Consumes: `authRepository` (P2-5.4).
- Produces: `@riverpod class SignInViewModel extends _$SignInViewModel` with `FutureOr<void> build()` and `Future<void> signInWithGoogle()`.

- [ ] **Step 1: Rewrite the view model**

Rewrite `lib/features/auth/ui/sign_in_view_model.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/auth_repository.dart';

part 'sign_in_view_model.g.dart';

/// Drives the login screen. Google in Phase 2 P2-5; Apple added in P2-6.
@riverpod
class SignInViewModel extends _$SignInViewModel {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }
}
```

- [ ] **Step 2: Update the login screen to the new view model name**

In `lib/features/auth/ui/login_screen.dart`, replace references to the old `authenticationControllerProvider`/`AuthenticationController` with `signInViewModelProvider`/`SignInViewModel`, and the sign-in call with `ref.read(signInViewModelProvider.notifier).signInWithGoogle()`. Keep the existing `ref.listen(...)` navigation trigger, but note post-login navigation is finalized in P2-5.9 (router redirect); the screen's listen may show errors via a snackbar/`AsyncError` state. Keep the single Google button (Apple button added in P2-6).

- [ ] **Step 3: Generate and verify analyze + build**

Run (from `peppercheck_flutter/`):

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter analyze --no-fatal-infos lib/features/auth/ 2>&1 | tail -10
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add peppercheck_flutter/lib/features/auth/ui/
git commit -m "feat(flutter): SignInViewModel and login screen on Firebase Google"
```

---

### Task P2-5.8: Migrate the 7 auth consumers to the current-user contract

**Files (modify):**
- `lib/app/routing/app_router.dart`
- `lib/features/matching/presentation/controllers/referee_availability_controller.dart`
- `lib/features/profile/presentation/providers/current_profile_provider.dart`
- `lib/features/home/presentation/widgets/task_card.dart`
- `lib/features/profile/presentation/avatar_edit_controller.dart`
- `lib/features/profile/presentation/username_edit_controller.dart`
- `lib/features/notification/application/fcm_service.dart` (listener only; token gating in P2-5.9)

> These are exactly the consumers of our own `currentUserProvider` / `authStateChangesProvider` whose types changed. Each now reads `currentAppUserProvider` (an `AppUser?`) and uses `AppUser.internalUserId` in place of the Supabase `user.id`. **Do not migrate** sites reading `Supabase.instance.client.auth.currentUser?.id` directly (judgement/evidence/task/report/billing) — they still compile and stay non-functional (§3).

- [ ] **Step 1: Router redirect guard**

In `lib/app/routing/app_router.dart`:
- Replace `final authState = ref.watch(authStateChangesProvider);` and `final isLoggedIn = authState.value?.session != null;` with:
  ```dart
  final isLoggedIn = ref.watch(isFirebaseAuthenticatedProvider);
  ```
  (import `package:peppercheck_flutter/features/auth/application/auth_state.dart`). Keep the redirect logic (logged-in on `/` → `/home`; not-logged-in off `/` → `/`). Full `/me`-failure handling lands in P2-5.9.

- [ ] **Step 2: `referee_availability_controller.dart`**

Replace the four `...session?.user.id` reads with the internal UUID from the contract. Because the controller needs the id synchronously in places, read the resolved `AppUser`:

```dart
final userId =
    ref.watch(currentAppUserProvider).valueOrNull?.internalUserId;
```

Guard null exactly as the old `session?.user.id` null path did (no-op / empty when signed out). Apply to all four sites (the `watch` at the top, and the three `read` sites use `ref.read(currentAppUserProvider).valueOrNull?.internalUserId`).

- [ ] **Step 3: `current_profile_provider.dart`**

Replace `final user = ref.watch(currentUserProvider);` / `user.id` with:

```dart
final user = ref.watch(currentAppUserProvider).valueOrNull;
if (user == null) return null; // or the existing signed-out behavior
... ref.watch(profileRepositoryProvider).fetchProfile(user.internalUserId);
```

- [ ] **Step 4: `task_card.dart`**

Replace `final currentUserId = ref.watch(currentUserProvider)?.id ?? '';` with:

```dart
final currentUserId =
    ref.watch(currentAppUserProvider).valueOrNull?.internalUserId ?? '';
```

- [ ] **Step 5: `avatar_edit_controller.dart` and `username_edit_controller.dart`**

In each, replace `final user = ref.read(currentUserProvider);` + null-guard + `user.id` with:

```dart
final user = ref.read(currentAppUserProvider).valueOrNull;
if (user == null) return; // keep the existing early-return/error behavior
... updateAvatar(user.internalUserId, cropped);   // or updateUsername(user.internalUserId, trimmed)
```

- [ ] **Step 6: `fcm_service.dart` listener**

Replace the `Supabase.instance.client.auth.onAuthStateChange.listen(...)` (L55-60) with a listen on the Firebase auth-state provider. Since `fcm_service` is a plain service, watch via the container/ref it already holds; listen to `authStateChangesProvider` and, on a non-null user, call `_upsertCurrentToken()` — but token registration itself is gated off in P2-5.9, so this listener becomes a no-op-guarded hook. Remove the `supabase_flutter` import. (If `fcm_service` cannot easily read a Riverpod provider, have it expose an `onSignedIn()` method the auth-state watcher calls; keep it minimal.)

- [ ] **Step 7: Delete the obsolete Supabase current-user provider**

Search for any remaining references to the removed `currentUserProvider` / `authStateChangesProvider` (Supabase versions):

```bash
grep -rn "currentUserProvider" peppercheck_flutter/lib peppercheck_flutter/test
```

Every hit must now be the new `currentAppUserProvider` or migrated. Remove the old provider definition if any stub remains.

- [ ] **Step 8: Generate, analyze, build**

Run (from `peppercheck_flutter/`):

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter analyze --no-fatal-infos 2>&1 | tail -15
```

Expected: no errors. (Direct-Supabase-auth consumers still compile.)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(flutter): migrate auth consumers to the internal current-user contract"
```

---

### Task P2-5.9: Post-login navigation + FCM token gating + composition wiring

**Files:**
- Modify: `lib/app/routing/app_router.dart`
- Modify: `lib/features/notification/data/notification_repository.dart`
- Modify: `lib/app/app_startup.dart`

- [ ] **Step 1: Gate navigation on `/me` resolution and add the limbo escape**

In `app_router.dart`, the app should enter past login only when Firebase-authenticated **and** `currentAppUser` resolves. Extend the redirect: while `isFirebaseAuthenticated` is true but `currentAppUserProvider` is `AsyncLoading`, stay on a loading affordance; if `currentAppUserProvider` is `AsyncError`, route to a state that offers **retry + sign-out** (not a `/home` limbo). Concretely, watch both:

```dart
final isLoggedIn = ref.watch(isFirebaseAuthenticatedProvider);
final me = ref.watch(currentAppUserProvider);
// signed in to Firebase but /me failed -> keep on login with an error affordance
if (isLoggedIn && me.hasError) return '/';
```

Surface the retry/sign-out affordance on the login screen when `signInViewModel`/`currentAppUser` is in error (provisioning is idempotent, so retry — a refetch of `currentAppUserProvider` — is safe). Keep the redirect otherwise: resolved `AppUser` on `/` → `/home`.

- [ ] **Step 2: Gate FCM token registration off until Phase 3**

In `notification_repository.dart`, the FCM upsert is keyed on the Supabase current user (`_supabase.auth.currentUser`), which is null after the auth switch. Replace the silent no-op with an explicit disabled guard so intent is legible:

```dart
Future<void> upsertToken(String token) async {
  // Disabled until the notification feature migrates to the Go API (Phase 3).
  // Token sync was keyed on the Supabase session, which no longer exists on the
  // auth path. Re-enable when notifications move; do not silently no-op.
  return;
}
```

Keep `deleteToken` similarly guarded. Do not remove the method signatures (callers stay).

- [ ] **Step 3: Wire the Firebase id-token override at composition**

In `lib/app/app_startup.dart`, add `idTokenProvider` to the root `ProviderContainer` overrides so `core/network` gets real tokens:

```dart
final container = ProviderContainer(
  overrides: [
    appEnvironmentProvider.overrideWithValue(config.environment),
    idTokenProviderProvider.overrideWith(firebaseIdTokenProvider),
  ],
);
```

Note: Riverpod codegen generates the provider `idTokenProviderProvider` from the `idTokenProvider` function (function name + `Provider` suffix) — override the generated `idTokenProviderProvider`, not the bare function. Import `firebaseIdTokenProvider` from `features/auth/application/auth_state.dart` and `idTokenProviderProvider` from `core/network/id_token_provider.dart` (via its generated part). Keep `Supabase.initialize(...)`, `Firebase.initializeApp()`, and `GoogleSignIn.instance.initialize()` exactly as they are.

- [ ] **Step 4: Generate, analyze, flavored build**

Run (from `peppercheck_flutter/`):

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter analyze --no-fatal-infos 2>&1 | tail -10
flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10
```

Expected: analyze clean, build succeeds.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(flutter): gate nav on /me, disable FCM sync, wire Firebase id-token"
```

---

### Task P2-5.10: Update the broken `username_edit_controller` test

**Files:**
- Modify: `test/features/profile/presentation/username_edit_controller_test.dart`

> This test overrode `currentUserProvider.overrideWithValue(createMockUser('user-123'))` with a Supabase `User`. After P2-5.8 the controller reads `currentAppUserProvider`. Update the override and the fixture.

- [ ] **Step 1: Replace the Supabase user fixture with an `AppUser` override**

- Remove the `package:supabase_flutter` import and `createMockUser`.
- Override `currentAppUserProvider` with a resolved `AppUser`:

```dart
currentAppUserProvider.overrideWith((ref) async => AppUser(
      internalUserId: 'user-123',
      issuer: 'iss',
      status: 'active',
      createdAt: DateTime.utc(2026),
    )),
```

- Update the expected `updateUsername` argument to `'user-123'` (unchanged value; now sourced from `internalUserId`).

- [ ] **Step 2: Run the test**

Run: `flutter test test/features/profile/presentation/username_edit_controller_test.dart`
Expected: PASS.

- [ ] **Step 3: Run the full Flutter test suite**

Run: `flutter test 2>&1 | tail -15`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add peppercheck_flutter/test/features/profile/presentation/username_edit_controller_test.dart
git commit -m "test(flutter): override the internal current-user contract in username test"
```

---

### Task P2-5.11: CI import-boundary checks

**Files:**
- Create: `scripts/check-flutter-imports.sh`
- Modify: `.github/workflows/ci-flutter.yml`

- [ ] **Step 1: Write the check script**

Create `scripts/check-flutter-imports.sh`:

```bash
#!/usr/bin/env bash
# Enforces Phase 2 import boundaries in the Flutter app:
#   1. firebase_auth may only be imported under lib/features/auth/.
#   2. the authenticated-user path (features/auth, core/network) must not
#      import supabase_flutter.
# The "Dio construction only in core/network" rule from the design (spec §8) is
# deliberately NOT enforced yet: evidence/profile still build Dio for R2 uploads
# until their own migration phase. Add that check when those features move.
set -euo pipefail
cd "$(dirname "$0")/.."
lib=peppercheck_flutter/lib
fail=0

bad_fb=$(grep -rl "package:firebase_auth/" "$lib" \
  | grep -v "^$lib/features/auth/" || true)
if [ -n "$bad_fb" ]; then
  echo "ERROR: firebase_auth imported outside lib/features/auth/:"
  echo "$bad_fb"
  fail=1
fi

bad_sb=$(grep -rl "package:supabase_flutter/" \
  "$lib/features/auth" "$lib/core/network" || true)
if [ -n "$bad_sb" ]; then
  echo "ERROR: supabase_flutter imported on the auth path (features/auth, core/network):"
  echo "$bad_sb"
  fail=1
fi

if [ "$fail" -eq 0 ]; then echo "Flutter import boundaries OK"; fi
exit "$fail"
```

Make it executable: `chmod +x scripts/check-flutter-imports.sh`

- [ ] **Step 2: Run it locally to confirm it passes**

Run: `./scripts/check-flutter-imports.sh`
Expected: `Flutter import boundaries OK` (exit 0). If it fails, a stray import remains from P2-5.8 — fix it.

- [ ] **Step 3: Add the step to CI**

In `.github/workflows/ci-flutter.yml`, add a step before `flutter test` (it needs no Flutter toolchain — pure grep):

```yaml
      - name: Check import boundaries
        run: ./scripts/check-flutter-imports.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/check-flutter-imports.sh .github/workflows/ci-flutter.yml
git commit -m "ci(flutter): enforce firebase_auth and supabase auth-path import boundaries"
```

---

## PR P2-6 — Apple Sign-In + operator/infra checklist

### Task P2-6.1: Add `sign_in_with_apple` + `crypto`; nonce utility

**Files:**
- Modify: `peppercheck_flutter/pubspec.yaml`
- Create: `lib/features/auth/data/apple_nonce.dart`
- Test: `test/features/auth/data/apple_nonce_test.dart`

**Interfaces:**
- Produces: `({String raw, String sha256Hex}) generateAppleNonce([Random? rng])` — a raw nonce and its SHA-256 hex digest.

- [ ] **Step 1: Add dependencies**

Run (from `peppercheck_flutter/`):

```bash
flutter pub add sign_in_with_apple crypto
```

Expected: resolves `sign_in_with_apple 7.0.1` and `crypto` (SHA-256).

- [ ] **Step 2: Write the failing test**

Create `test/features/auth/data/apple_nonce_test.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/auth/data/apple_nonce.dart';

void main() {
  test('sha256Hex is the SHA-256 of the raw nonce', () {
    final nonce = generateAppleNonce(Random(1));
    final expected = sha256.convert(utf8.encode(nonce.raw)).toString();
    expect(nonce.sha256Hex, expected);
  });

  test('raw nonce is sufficiently long and URL-safe', () {
    final nonce = generateAppleNonce(Random(2));
    expect(nonce.raw.length, greaterThanOrEqualTo(32));
    expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(nonce.raw), isTrue);
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/features/auth/data/apple_nonce_test.dart`
Expected: FAIL — `generateAppleNonce` undefined.

- [ ] **Step 4: Implement**

Create `lib/features/auth/data/apple_nonce.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A Sign in with Apple nonce: a random [raw] string sent to Apple as the
/// SHA-256 [sha256Hex], then passed back to Firebase as the raw value to bind
/// the credential and prevent replay.
typedef AppleNonce = ({String raw, String sha256Hex});

const _charset =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz._-';

/// Generates a 32-char random nonce and its SHA-256 hex digest. [rng] is
/// injectable for deterministic tests; production passes `Random.secure()`.
AppleNonce generateAppleNonce([Random? rng]) {
  final random = rng ?? Random.secure();
  final raw = List.generate(
    32,
    (_) => _charset[random.nextInt(_charset.length)],
  ).join();
  final digest = sha256.convert(utf8.encode(raw)).toString();
  return (raw: raw, sha256Hex: digest);
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/auth/data/apple_nonce_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add peppercheck_flutter/pubspec.yaml peppercheck_flutter/pubspec.lock peppercheck_flutter/lib/features/auth/data/apple_nonce.dart peppercheck_flutter/test/features/auth/data/apple_nonce_test.dart
git commit -m "feat(flutter): add Sign in with Apple deps and nonce utility"
```

---

### Task P2-6.2: `signInWithApple` + account-link handling

**Files:**
- Modify: `lib/features/auth/data/auth_repository.dart`
- Test: `test/features/auth/data/apple_sign_in_test.dart`

**Interfaces:**
- Consumes: `generateAppleNonce` (P2-6.1).
- Produces on `AuthRepository`:
  - `Future<void> signInWithApple()`.
  - `Future<void> linkAppleToExisting({required AuthCredential pending, required AuthCredential existing})` — called only after explicit user consent.
  - A typed signal for the UI when linking is needed: throw `AccountLinkRequiredException(email, pendingCredential)` on `account-exists-with-different-credential`.

- [ ] **Step 1: Write the failing tests (confirm + cancel paths)**

Create `test/features/auth/data/apple_sign_in_test.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';

import 'apple_sign_in_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseAuth>(),
  MockSpec<User>(),
  MockSpec<UserCredential>(),
])
void main() {
  test('account-exists-with-different-credential surfaces a link request',
      () async {
    final auth = MockFirebaseAuth();
    final repo = AuthRepository.forAppleTest(auth);
    when(auth.signInWithCredential(any)).thenThrow(
      FirebaseAuthException(
        code: 'account-exists-with-different-credential',
        email: 'a@example.com',
      ),
    );

    expect(
      () => repo.completeAppleSignIn(
        idToken: 'apple-id-token',
        rawNonce: 'nonce',
      ),
      throwsA(isA<AccountLinkRequiredException>()
          .having((e) => e.email, 'email', 'a@example.com')),
    );
  });

  test('linkAppleToExisting links only after consent (confirm path)', () async {
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(auth.signInWithCredential(any))
        .thenAnswer((_) async => MockUserCredential());
    when(auth.currentUser).thenReturn(user);
    when(user.linkWithCredential(any))
        .thenAnswer((_) async => MockUserCredential());
    final repo = AuthRepository.forAppleTest(auth);

    final apple = OAuthProvider('apple')
        .credential(idToken: 'apple-id-token', rawNonce: 'nonce');
    final existing = GoogleAuthProvider.credential(idToken: 'g');

    await repo.linkAppleToExisting(pending: apple, existing: existing);

    verify(user.linkWithCredential(apple)).called(1);
  });
}
```

> Add an `AuthRepository.forAppleTest(FirebaseAuth)` named constructor (Google not needed for these) or reuse the main constructor with mock Google — keep it minimal. The **cancel path** is a UI test (P2-6.3): declining consent must not call `linkWithCredential`.

- [ ] **Step 2: Run to verify it fails**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/data/apple_sign_in_test.dart
```

Expected: FAIL — symbols undefined.

- [ ] **Step 3: Implement**

In `lib/features/auth/data/auth_repository.dart` add (imports: `sign_in_with_apple`, `apple_nonce.dart`):

```dart
/// Raised when Apple's email matches an existing account under a different
/// provider that Firebase will not auto-link. The UI must obtain explicit user
/// consent before calling [AuthRepository.linkAppleToExisting]. Never merge on
/// an email string alone.
class AccountLinkRequiredException implements Exception {
  const AccountLinkRequiredException(this.email, this.pendingCredential);
  final String? email;
  final AuthCredential pendingCredential;
}
```

Add methods to `AuthRepository`:

```dart
Future<void> signInWithApple() async {
  final nonce = generateAppleNonce();
  final appleCredential = await SignInWithApple.getAppleIDCredential(
    scopes: const [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: nonce.sha256Hex,
  );
  final idToken = appleCredential.identityToken;
  if (idToken == null) {
    throw StateError('Apple sign-in returned no identity token');
  }
  await completeAppleSignIn(idToken: idToken, rawNonce: nonce.raw);
}

/// Exchanges the Apple identity token for a Firebase sign-in. On
/// account-exists-with-different-credential, raises
/// [AccountLinkRequiredException] instead of silently creating a second user.
Future<void> completeAppleSignIn({
  required String idToken,
  required String rawNonce,
}) async {
  final credential = OAuthProvider('apple').credential(
    idToken: idToken,
    rawNonce: rawNonce,
  );
  try {
    await _auth.signInWithCredential(credential);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'account-exists-with-different-credential') {
      throw AccountLinkRequiredException(e.email, credential);
    }
    rethrow;
  }
}

/// Links the pending Apple credential onto the existing account. Call ONLY
/// after explicit user consent and after re-authenticating with [existing].
Future<void> linkAppleToExisting({
  required AuthCredential pending,
  required AuthCredential existing,
}) async {
  await _auth.signInWithCredential(existing);
  final user = _auth.currentUser;
  if (user == null) throw StateError('re-auth failed before linking');
  await user.linkWithCredential(pending);
}
```

Add the `AuthRepository.forAppleTest` named constructor if you used it in the test (inject only `FirebaseAuth`; stub Google with a throwing default it never calls in these tests), or adjust the test to the main constructor.

- [ ] **Step 4: Regenerate and run**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/data/apple_sign_in_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add peppercheck_flutter/lib/features/auth/data/auth_repository.dart peppercheck_flutter/test/features/auth/data/apple_sign_in_test.dart peppercheck_flutter/test/features/auth/data/apple_sign_in_test.mocks.dart
git commit -m "feat(flutter): Apple sign-in with consent-gated account linking"
```

---

### Task P2-6.3: Apple button + link-consent UI (confirm & cancel)

**Files:**
- Modify: `lib/features/auth/ui/login_screen.dart`
- Modify: `lib/features/auth/ui/sign_in_view_model.dart`
- Test: `test/features/auth/ui/apple_link_flow_test.dart` (widget test)

**Interfaces:**
- Produces on `SignInViewModel`: `Future<void> signInWithApple()`; the view model catches `AccountLinkRequiredException` and exposes a state the screen renders as a consent dialog.

- [ ] **Step 1: Add `signInWithApple` to the view model**

In `sign_in_view_model.dart`:

```dart
Future<void> signInWithApple() async {
  state = const AsyncLoading();
  state = await AsyncValue.guard(
    () => ref.read(authRepositoryProvider).signInWithApple(),
  );
}
```

`AsyncError` carrying `AccountLinkRequiredException` is the signal the screen listens for.

- [ ] **Step 2: Add the Apple button and consent dialog to the login screen**

In `login_screen.dart`:
- Add an Apple sign-in button (below the Google button, `SizedBox(height: AppSizes.spacingSmall)` between them) that calls `ref.read(signInViewModelProvider.notifier).signInWithApple()`.
- In the existing `ref.listen(signInViewModelProvider, ...)`, when the error is `AccountLinkRequiredException`, show a consent dialog ("An account with this email already exists — link Apple to it?"):
  - **Confirm** → re-authenticate with the existing provider and call `linkAppleToExisting(...)`.
  - **Cancel** → dismiss, leave accounts separate, show a clear message, return to sign-in. Never link on cancel.

Use existing i18n (slang) keys; add new keys under the auth namespace if needed (Japanese source in the `_ja` slang file, English in the base). Do not hardcode UI strings.

- [ ] **Step 3: Write the widget test for confirm + cancel**

Create `test/features/auth/ui/apple_link_flow_test.dart`: pump `LoginScreen` with `signInViewModelProvider` overridden to emit `AsyncError(AccountLinkRequiredException('a@example.com', <fake cred>))`; assert the consent dialog appears; tapping **Cancel** does not invoke `linkAppleToExisting` (verify on a mock repo) and dismisses; tapping **Confirm** invokes it once. Use `ProviderContainer` overrides with a `MockAuthRepository`.

- [ ] **Step 4: Generate, run the test, build**

Run (from `peppercheck_flutter/`):

```bash
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
flutter test test/features/auth/ui/apple_link_flow_test.dart
flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10
```

Expected: test passes, build succeeds.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(flutter): Apple sign-in button with consent/cancel link flow"
```

---

### Task P2-6.4: iOS Sign in with Apple capability (per scheme)

**Files:**
- Modify: `ios/Runner/Runner.entitlements` (and per-flavor entitlements if separate), Xcode project capability.

> Native config; verified by an iOS build. Follow the project's flavor/scheme rule (memory: schemes named exactly `dev.xcscheme` / `staging.xcscheme` / `production.xcscheme`).

- [ ] **Step 1: Add the capability**

Add `com.apple.developer.applesignin` = `["Default"]` to the Runner entitlements for each flavor. In Xcode: Runner target → Signing & Capabilities → + Capability → Sign in with Apple, for each build configuration. Confirm the entitlements file(s) referenced by the dev/staging/production schemes include the key.

- [ ] **Step 2: Verify an iOS build**

Run (from `peppercheck_flutter/`):

```bash
flutter build ios --debug --no-codesign -t lib/main_dev.dart 2>&1 | tail -10
```

Expected: build succeeds (no-codesign avoids signing setup in CI/local).

- [ ] **Step 3: Commit**

```bash
git add peppercheck_flutter/ios/
git commit -m "feat(ios): add Sign in with Apple capability per flavor"
```

---

### Task P2-6.5: Operator/infra checklist + release-checklist entries

**Files:**
- Create: `docs/operations/phase2-auth-operator-checklist.md`
- Add release-checklist Pending entries (via the release-checklist skill).

- [ ] **Step 1: Write the operator checklist**

Create `docs/operations/phase2-auth-operator-checklist.md` capturing spec §7 steps 1–8, per environment (dev / staging / production Firebase projects):
1. Firebase — enable Google provider; confirm OAuth consent screen.
2. Firebase — one-account-per-email (auto-link trusted verified providers).
3. Android SHA-1 + SHA-256 per flavor (dev debug keystore at `~/.config/.android/`, staging, production) in the matching Firebase project.
4. Firebase — enable Apple provider; register Services ID + key.
5. Apple Developer — Sign in with Apple capability on each App ID; create Services ID + key (step 4 input).
6. Xcode — Sign in with Apple capability per flavor scheme (done in P2-6.4).
7. `FIREBASE_PROJECT_ID` injection — real per-env project ID for the deployed api (replaces the dummy local default).
8. E2E smoke (per platform, real device): Google and Apple for the **same verified email** → the **same** internal user; Apple Hide-My-Email relay → a **separate** account.

- [ ] **Step 2: Record release-checklist Pending entries**

Invoke the `release-checklist` skill and add Pending operator items, tagged to the environment and the introducing PR: `FIREBASE_PROJECT_ID` injection (P2-2, backend — already merged); Google provider + one-account-per-email + Android SHA (P2-5); Apple provider + Apple Developer + Xcode (P2-6). Each must be completed before that environment's release.

- [ ] **Step 3: Commit**

```bash
git add docs/operations/phase2-auth-operator-checklist.md
git commit -m "docs(ops): Phase 2 auth operator/infra checklist"
```

---

### Task P2-6.6: Full suite + import checks + flavored builds

**Files:** none (verification).

- [ ] **Step 1: Run the whole Flutter test suite and import checks**

Run (from repo root):

```bash
./scripts/check-flutter-imports.sh
cd peppercheck_flutter && dart format --set-exit-if-changed --line-length 80 lib test 2>&1 | tail -5
flutter analyze --no-fatal-infos 2>&1 | tail -10
flutter test 2>&1 | tail -15
```

Expected: import boundaries OK; format clean; analyze clean; all tests pass.

- [ ] **Step 2: Flavored debug build**

Run: `flutter build apk --debug -t lib/main_dev.dart 2>&1 | tail -10`
Expected: succeeds.

- [ ] **Step 3: Commit any formatting fixes**

```bash
git add -A
git commit -m "chore(flutter): format and lint cleanup for Phase 2 Flutter"
```

---

### Task P2-6.7: Single emulator end-to-end verification pass

**Files:** none (manual/emulator verification, per project convention — the one emulator pass for all of Phase 2 Flutter).

> Requires the operator to have completed the P2-6.5 checklist for the **dev** Firebase project (Google + Apple providers enabled, dev Android SHA registered) and a running dev api reachable via Caddy on the loopback host. This is an operator-verified step (memory: let the user verify irreversible/e2e actions personally).

- [ ] **Step 1: Start the dev backend**

Ensure the Go api + Postgres + Caddy dev stack is up (Compose) and `GET /api/v1/me` responds `401 unauthenticated` to an unauthenticated curl through Caddy on `:80`.

- [ ] **Step 2: Run the app on the Android emulator**

Run (from `peppercheck_flutter/`):

```bash
flutter run -t lib/main_dev.dart
```

- [ ] **Step 3: Verify the identity slice end-to-end**

Confirm, and record the result for the operator to sign off:
- Google sign-in succeeds → app resolves `GET /api/v1/me` → lands past login.
- Sign out returns to the login screen; no crash; re-sign-in works.
- Apple sign-in (iOS simulator/device) with the **same verified email** resolves to the **same** internal `user.id` (no duplicate user).
- Killing the api mid-session and re-triggering `/me` shows the retry + sign-out affordance (no limbo), and recovers when the api returns.

- [ ] **Step 4: Note the outcome**

No code commit unless a defect is found. If a defect surfaces, use `superpowers:systematic-debugging` and add a regression test before fixing.

---

## Self-Review

**1. Spec coverage** (spec `2026-07-24-phase2-identity-client-boundary-design.md`):
- §6.1 `core/network` ApiClient — base URL by env (P2-4.2/4.6), auth interceptor via `IdTokenProvider` (P2-4.4/4.5), 401 single retry idempotent GET (P2-4.5), request-id (P2-4.5), timeouts (P2-4.5), no non-idempotent retry (P2-4.5, GET-only method), error mapping → `ApiException` (P2-4.3/4.5), dev cleartext (P2-4.7), `firebase_auth` dep (P2-4.1). ✅
- §6.2 `features/auth` — Firebase Google (P2-5.4), sign-out idempotent legs (P2-5.4), auth-state on Firebase (P2-5.6), current-user contract exposing internal UUID (P2-5.6), remove Supabase from auth path (P2-5.4/5.6/5.9, CI P2-5.11), rename `authentication`→`auth` (P2-5.1), migrate consumers (P2-5.8), FCM disable + listener move (P2-5.8/5.9). ✅
- §6.3 post-login nav + `/me`-failure retry/sign-out (P2-5.9). ✅
- §7 Apple + nonce + linkWithCredential confirm/cancel + Hide-My-Email (P2-6.1/6.2/6.3); operator/infra checklist (P2-6.5); Xcode capability (P2-6.4). ✅
- §8 tests: ApiClient (P2-4.5), auth-state/contract/sign-out (P2-5.4/5.6), Apple confirm+cancel (P2-6.2/6.3); CI import checks (P2-5.11, with the documented Dio-check deferral); single emulator pass (P2-6.7). ✅
- §9 edge cases: link on email-string-alone forbidden (P2-6.2), partial sign-out (P2-5.4), Hide-My-Email no retroactive merge (P2-6.2 behavior + P2-6.7 smoke), `/me` failure no limbo (P2-5.9), username generation deferred to Phase 3 (out of scope — noted). ✅
- §12 done criteria — all mapped except the backend-only ones (already merged).

**Deferred with reason (documented, not a gap):** the "Dio construction only in `core/network`" CI check (spec §8) is deferred because `evidence`/`profile` still construct Dio for R2 uploads until their migration phase (§3 narrowing). Recorded in Task P2-5.11's script comment and Global Constraints.

**2. Placeholder scan:** no TBD/TODO/"add error handling"/"similar to Task N"; every code step carries real code. Native-config and operator steps (P2-4.7, P2-6.4, P2-6.5, P2-6.7) are verified by build/emulator rather than unit tests, which is correct for those artifacts.

**3. Type consistency:** `IdTokenProvider` signature identical in P2-4.4/4.5/4.6/5.6. `AppUser.internalUserId` used consistently in P2-5.2/5.3/5.5/5.6/5.8/5.10. `currentAppUserProvider` name consistent P2-5.6→5.8→5.9→5.10. `ApiClient.getJson('/api/v1/me')` consistent P2-4.5/5.5. `AccountLinkRequiredException(email, pendingCredential)` consistent P2-6.2/6.3.
