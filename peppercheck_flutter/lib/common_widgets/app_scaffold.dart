import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final int currentIndex;
  final String? title;
  final List<Widget>? actions;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.currentIndex = 0,
    this.title,
    this.actions,
  });

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/payments');
        break;
      case 2:
        // TODO: Navigate to Profile
        break;
    }
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (currentIndex == 0) {
      return FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to Create Task
        },
        backgroundColor: AppColors.accentYellow,
        foregroundColor: AppColors.textBlack,
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

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
                  icon: Icon(Icons.payments, color: AppColors.textBlack),
                  label: t.nav.payments,
                ),
                NavigationDestination(
                  icon: Icon(Icons.person, color: AppColors.textBlack),
                  label: t.nav.profile,
                ),
              ],
              selectedIndex: currentIndex,
              onDestinationSelected: (index) => _onItemTapped(index, context),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }
}
