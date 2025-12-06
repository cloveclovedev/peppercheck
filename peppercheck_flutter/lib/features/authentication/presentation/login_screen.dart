import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:peppercheck_flutter/features/authentication/presentation/authentication_controller.dart';
import 'package:peppercheck_flutter/gen/assets.gen.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';

import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Better approach: use listen to navigate
    ref.listen<AsyncValue<void>>(authenticationControllerProvider, (_, state) {
      if (state is AsyncData) {
        context.go('/home');
      } else if (state is AsyncError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error.toString())));
      }
    });

    final state = ref.watch(authenticationControllerProvider);

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
                                .read(authenticationControllerProvider.notifier)
                                .signInWithGoogle();
                          },
                    child: state.isLoading
                        ? const CircularProgressIndicator()
                        : SvgPicture.asset(
                            Assets.images.androidNeutralRdCtn,
                            height: 50,
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
