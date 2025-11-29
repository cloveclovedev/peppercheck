import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:peppercheck_flutter/gen/assets.gen.dart';
import 'package:peppercheck_flutter/app/theme/colors.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Assets.images.paperTexture.provider(),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 30),
                  Assets.images.peppercheckLogo.image(height: 140),
                  const Spacer(flex: 2),
                  Text(
                    'PEPPERCHECK',
                    style: GoogleFonts.luckiestGuy(
                      fontSize: 48,
                      color: AppColors.accentRed,
                    ),
                  ),
                  const Spacer(flex: 30),
                  GestureDetector(
                    onTap: () {
                      context.go('/home');
                    },
                    child: SvgPicture.asset(
                      Assets.images.androidNeutralRdCtn,
                      height: 50, // Adjust height as needed
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
