import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/colors.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final int currentIndex;
  final ValueChanged<int>? onNavigationSelected;
  final String? title;
  final List<Widget>? actions;

  const AppScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.appBar,
    this.currentIndex = 0,
    this.onNavigationSelected,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // The Scaffold itself is transparent to let AppBackground show through
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar:
          appBar ??
          (title != null
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  title: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: actions,
                )
              : null),
      body: body,
      bottomNavigationBar: SafeArea(
        child: Padding(
          // Removed bottom padding as requested (was 8)
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.accentYellow,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home, color: AppColors.textBlack),
                  label: t.nav.home,
                ),
                NavigationDestination(
                  icon: Icon(Icons.person, color: AppColors.textBlack),
                  label: t.nav.profile,
                ),
              ],
              selectedIndex: currentIndex,
              onDestinationSelected: onNavigationSelected,
            ),
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
