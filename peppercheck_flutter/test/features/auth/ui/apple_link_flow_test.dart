import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';
import 'package:peppercheck_flutter/features/auth/ui/login_screen.dart';
import 'package:peppercheck_flutter/features/auth/ui/sign_in_view_model.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

import 'apple_link_flow_test.mocks.dart';

/// Test double whose `build()` immediately (post-build, via a microtask —
/// setting `state` synchronously *during* build is disallowed) puts the
/// notifier into the `AsyncError(AccountLinkRequiredException)` state the
/// screen renders as the link-consent dialog. `confirmAppleLink` and
/// `cancelAppleLink` are inherited unmodified from [SignInViewModel], so the
/// test exercises the real confirm/cancel logic against a mocked
/// [AuthRepository].
class _LinkRequiredSignInViewModel extends SignInViewModel {
  _LinkRequiredSignInViewModel(this._error);
  final AccountLinkRequiredException _error;

  @override
  FutureOr<void> build() {
    Future.microtask(() {
      state = AsyncError<void>(_error, StackTrace.current);
    });
  }
}

@GenerateNiceMocks([MockSpec<AuthRepository>()])
void main() {
  late MockAuthRepository authRepository;
  late AccountLinkRequiredException error;

  setUp(() {
    authRepository = MockAuthRepository();
    error = AccountLinkRequiredException(
      'a@example.com',
      GoogleAuthProvider.credential(idToken: 'apple-pending-id-token'),
    );
  });

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    // A minimal router (rather than a bare MaterialApp(home:)) because
    // LoginScreen's `ref.listen` calls `context.go('/home')` on AsyncData —
    // reached via the cancel path, which resets state to AsyncData(null).
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          isFirebaseAuthenticatedProvider.overrideWithValue(false),
          signInViewModelProvider.overrideWith(
            () => _LinkRequiredSignInViewModel(error),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // Let the notifier's post-build microtask land the AsyncError state and
    // the resulting rebuild show the dialog.
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'shows the link-consent dialog for AccountLinkRequiredException',
    (tester) async {
      await pumpLoginScreen(tester);

      expect(find.text(t.login.appleLink.title), findsOneWidget);
      expect(find.text(t.login.appleLink.body), findsOneWidget);
      expect(find.text(t.login.appleLink.confirm), findsOneWidget);
      expect(find.text(t.login.appleLink.cancel), findsOneWidget);
    },
  );

  testWidgets('cancel dismisses the dialog and never links', (tester) async {
    await pumpLoginScreen(tester);

    await tester.tap(find.text(t.login.appleLink.cancel));
    await tester.pumpAndSettle();

    verifyNever(
      authRepository.linkAppleToExisting(
        pending: anyNamed('pending'),
        existing: anyNamed('existing'),
      ),
    );
    expect(find.text(t.login.appleLink.title), findsNothing);
    expect(find.text(t.login.appleLink.cancelled), findsOneWidget);
  });

  testWidgets('confirm re-authenticates with Google then links exactly once', (
    tester,
  ) async {
    when(
      authRepository.googleCredential(),
    ).thenAnswer((_) async => GoogleAuthProvider.credential(idToken: 'g'));
    // Never resolves: the test only needs to observe the call, not the
    // post-link navigation (which would require a GoRouter in the tree).
    when(
      authRepository.linkAppleToExisting(
        pending: anyNamed('pending'),
        existing: anyNamed('existing'),
      ),
    ).thenAnswer((_) => Completer<void>().future);

    await pumpLoginScreen(tester);

    await tester.tap(find.text(t.login.appleLink.confirm));
    // Advance through: dialog pop -> confirmAppleLink -> googleCredential
    // await -> linkAppleToExisting call.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    verify(
      authRepository.linkAppleToExisting(
        pending: anyNamed('pending'),
        existing: anyNamed('existing'),
      ),
    ).called(1);
  });
}
