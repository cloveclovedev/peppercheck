import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/features/about/presentation/app_explanation_bottom_sheet.dart';
import 'package:peppercheck_flutter/features/auth/application/auth_state.dart';
import 'package:peppercheck_flutter/features/auth/data/auth_repository.dart';
import 'package:peppercheck_flutter/features/auth/ui/sign_in_view_model.dart';
import 'package:peppercheck_flutter/gen/assets.gen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Better approach: use listen to navigate
    ref.listen<AsyncValue<void>>(signInViewModelProvider, (_, state) {
      if (state is AsyncData) {
        context.go('/home');
      } else if (state is AsyncError) {
        final error = state.error;
        if (error is AccountLinkRequiredException) {
          _showAppleLinkDialog(context, ref, error);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    });

    final state = ref.watch(signInViewModelProvider);

    // Firebase-authenticated but `/me` hasn't resolved yet: the router keeps
    // the user on this route (see `app_router.dart`), so show a loading
    // affordance while it's in flight, or a retry + sign-out affordance if it
    // failed — never a silent limbo.
    final isFirebaseAuthenticated = ref.watch(isFirebaseAuthenticatedProvider);
    final me = ref.watch(currentAppUserProvider);
    if (isFirebaseAuthenticated && !me.hasValue) {
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: me.hasError
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.loginScreenHorizontalPadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not load your account.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSizes.spacingMedium),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(currentAppUserProvider),
                            child: const Text('Retry'),
                          ),
                          const SizedBox(height: AppSizes.spacingSmall),
                          TextButton(
                            onPressed: () =>
                                ref.read(authRepositoryProvider).signOut(),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.loginScreenHorizontalPadding,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 30),
                  Assets.images.peppercheckLogo.image(
                    height: AppSizes.loginPeppercheckIconHeight,
                  ),
                  const Spacer(flex: 2),
                  Text(
                    t.login.title,
                    style: GoogleFonts.luckiestGuy(
                      fontSize: AppSizes.loginPeppercheckTitleFontSize,
                      color: AppColors.accentRed,
                    ),
                  ),
                  const Spacer(flex: 30),
                  GestureDetector(
                    onTap: state.isLoading
                        ? null
                        : () {
                            ref
                                .read(signInViewModelProvider.notifier)
                                .signInWithGoogle();
                          },
                    child: state.isLoading
                        ? const CircularProgressIndicator()
                        : SvgPicture.asset(
                            Assets.images.androidNeutralRdCtn,
                            height: 50,
                          ),
                  ),
                  // Apple sign-in is offered on iOS only (native flow). On
                  // Android it would need a Services ID + web OAuth flow; users
                  // sign in with Google there instead.
                  if (Platform.isIOS) ...[
                    const SizedBox(height: AppSizes.spacingSmall),
                    SignInWithAppleButton(
                      onPressed: state.isLoading
                          ? null
                          : () {
                              ref
                                  .read(signInViewModelProvider.notifier)
                                  .signInWithApple();
                            },
                    ),
                  ],
                  const SizedBox(height: AppSizes.spacingMedium),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showAppExplanationBottomSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.spacingTiny,
                      ),
                      child: Text(
                        t.login.aboutLink,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the Apple↔existing-account link-consent dialog. Confirm links after
/// re-authenticating with the existing provider; cancel dismisses without
/// ever linking (see [SignInViewModel.cancelAppleLink]).
void _showAppleLinkDialog(
  BuildContext context,
  WidgetRef ref,
  AccountLinkRequiredException error,
) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(t.login.appleLink.title),
      content: Text(t.login.appleLink.body),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            ref.read(signInViewModelProvider.notifier).cancelAppleLink();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.login.appleLink.cancelled)),
            );
          },
          child: Text(t.login.appleLink.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            ref
                .read(signInViewModelProvider.notifier)
                .confirmAppleLink(error.pendingCredential);
          },
          child: Text(t.login.appleLink.confirm),
        ),
      ],
    ),
  );
}
