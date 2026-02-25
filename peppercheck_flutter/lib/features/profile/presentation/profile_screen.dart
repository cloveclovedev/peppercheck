import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/features/matching/presentation/widgets/referee_availability_section.dart';
import 'package:peppercheck_flutter/features/matching/presentation/widgets/referee_blocked_dates_section.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: AppScaffold.scrollable(
        title: t.profile.title,
        currentIndex: 2,
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              const RefereeAvailabilitySection(),
              const SizedBox(height: AppSizes.sectionGap),
              const RefereeBlockedDatesSection(),
            ]),
          ),
        ],
      ),
    );
  }
}
