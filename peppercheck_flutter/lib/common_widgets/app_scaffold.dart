import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class AppScaffold extends StatelessWidget {
  final Widget? _body;
  final List<Widget>? _slivers;
  final Future<void> Function()? _onRefresh;
  final bool useDefaultPadding;
  final PreferredSizeWidget? appBar;
  final int currentIndex;
  final String? title;
  final List<Widget>? actions;

  /// Creates a scaffold with a fixed body.
  /// Use this for screens that do not have a standard scrollable list layout,
  /// or require custom scrolling behavior not covered by [AppScaffold.scrollable].
  const AppScaffold.fixed({
    super.key,
    required Widget body,
    this.appBar,
    this.currentIndex = 0,
    this.title,
    this.actions,
  }) : _body = body,
       _slivers = null,
       _onRefresh = null,
       useDefaultPadding = false;

  /// Creates a scaffold with a scrollable list of slivers.
  /// Automatically handles bottom padding for the navigation bar and refresh indicator.
  const AppScaffold.scrollable({
    super.key,
    required List<Widget> slivers,
    Future<void> Function()? onRefresh,
    this.appBar,
    this.currentIndex = 0,
    this.title,
    this.actions,
    this.useDefaultPadding = true,
  }) : _slivers = slivers,
       _onRefresh = onRefresh,
       _body = null;

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/payments');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (currentIndex == 0) {
      return FloatingActionButton(
        onPressed: () {
          context.push('/create_task');
        },
        backgroundColor: AppColors.accentYellow,
        foregroundColor: AppColors.textPrimary,
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
      extendBody: true,
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
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: actions,
                )
              : null),
      body: _buildBody(context),
      bottomNavigationBar: SafeArea(
        child: Padding(
          // Removed bottom padding as requested (was 8)
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.screenHorizontalPadding,
            vertical: AppSizes.screenVerticalPadding,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(
                AppSizes.bottomNavigationBarBorderRadius,
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: currentIndex == -1
                  ? Colors.transparent
                  : AppColors.accentYellow,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home, color: AppColors.textPrimary),
                  label: t.nav.home,
                ),
                NavigationDestination(
                  icon: Icon(Icons.payments, color: AppColors.textPrimary),
                  label: t.nav.payments,
                ),
                NavigationDestination(
                  icon: Icon(Icons.person, color: AppColors.textPrimary),
                  label: t.nav.profile,
                ),
              ],
              selectedIndex: currentIndex == -1 ? 0 : currentIndex,
              onDestinationSelected: (index) => _onItemTapped(index, context),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_slivers != null) {
      List<Widget> contentSlivers = _slivers;

      // Apply centralized padding if requested
      if (useDefaultPadding) {
        contentSlivers = [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenHorizontalPadding,
              vertical: AppSizes.screenVerticalPadding,
            ),
            sliver: SliverMainAxisGroup(slivers: contentSlivers),
          ),
        ];
      }

      final bottomPadding = AppSizes.bottomNavigationBarHeight +
          MediaQuery.paddingOf(context).bottom;

      final scrollView = CustomScrollView(
        slivers: [
          ...contentSlivers,
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottomPadding),
          ),
        ],
      );

      if (_onRefresh != null) {
        return RefreshIndicator(onRefresh: _onRefresh, child: scrollView);
      }
      return scrollView;
    }
    return _body ?? const SizedBox.shrink();
  }
}
