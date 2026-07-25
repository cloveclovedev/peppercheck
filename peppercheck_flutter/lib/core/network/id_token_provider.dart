import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'id_token_provider.g.dart';

/// Supplies the current bearer token for authenticated API calls. Injected so
/// `core/network` never imports the Firebase SDK; `features/auth` provides the
/// Firebase-backed implementation and overrides [idTokenProvider] at app
/// composition (Phase 2 P2-5).
typedef IdTokenProvider =
    Future<String?> Function({required bool forceRefresh});

/// Default: no token. Replaced by the Firebase implementation at composition.
@riverpod
IdTokenProvider idTokenProvider(Ref ref) {
  return ({required bool forceRefresh}) async => null;
}
