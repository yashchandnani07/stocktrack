import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import '../routes/app_routes.dart';
import 'package:google_fonts/google_fonts.dart';

class AppNavigation extends StatelessWidget {
  final int currentIndex;
  final String userRole;
  final String userName;
  final String userId;
  final bool isActive;
  final String storeId;
  final String storeName;

  const AppNavigation({
    super.key,
    required this.currentIndex,
    required this.userRole,
    this.userName = '',
    this.userId = '',
    this.isActive = true,
    this.storeId = '',
    this.storeName = '',
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    if (isTablet) {
      return _TabletRail(
        currentIndex: currentIndex,
        userRole: userRole,
        userName: userName,
        userId: userId,
        isActive: isActive,
        storeId: storeId,
        storeName: storeName,
      );
    }
    return _PhoneBottomNav(
      currentIndex: currentIndex,
      userRole: userRole,
      userName: userName,
      userId: userId,
      isActive: isActive,
      storeId: storeId,
      storeName: storeName,
    );
  }

  static List<_NavItem> _getNavItems(String role) {
    final items = [
      _NavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        label: 'Inventory',
        route: AppRoutes.inventoryScreen,
      ),
      _NavItem(
        icon: Icons.category_outlined,
        activeIcon: Icons.category_rounded,
        label: 'Categories',
        route: AppRoutes.categoriesScreen,
      ),
    ];
    if (role == 'Owner' || role == 'Manager') {
      items.add(
        _NavItem(
          icon: Icons.history_outlined,
          activeIcon: Icons.history_rounded,
          label: 'Activity',
          route: AppRoutes.activityLogScreen,
        ),
      );
    }
    if (role == 'Owner') {
      items.add(
        _NavItem(
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          label: 'Team',
          route: AppRoutes.userManagementScreen,
        ),
      );
      items.add(
        _NavItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          label: 'Settings',
          route: AppRoutes.settingsScreen,
        ),
      );
    }
    return items;
  }

  static Map<String, dynamic> _routeArgs(
    String role, {
    String userName = '',
    String userId = '',
    bool isActive = true,
    String storeId = '',
    String storeName = '',
  }) {
    return {
      'role': role,
      'userName': userName,
      'userId': userId,
      'isActive': isActive,
      'storeId': storeId,
      'storeName': storeName,
    };
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

class _PhoneBottomNav extends StatelessWidget {
  final int currentIndex;
  final String userRole;
  final String userName;
  final String userId;
  final bool isActive;
  final String storeId;
  final String storeName;

  const _PhoneBottomNav({
    required this.currentIndex,
    required this.userRole,
    this.userName = '',
    this.userId = '',
    this.isActive = true,
    this.storeId = '',
    this.storeName = '',
  });

  @override
  Widget build(BuildContext context) {
    final items = AppNavigation._getNavItems(userRole);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outline, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final isActiveTab = index == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (!isActiveTab) {
                      if (!PermissionService.instance.canPerformAnyAction) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Your account has been disabled. Contact the owner.',
                              style: GoogleFonts.dmSans(fontSize: 13),
                            ),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                        return;
                      }
                      Navigator.pushReplacementNamed(
                        context,
                        items[index].route,
                        arguments: AppNavigation._routeArgs(
                          userRole,
                          userName: userName,
                          userId: userId,
                          isActive: isActive,
                          storeId: storeId,
                          storeName: storeName,
                        ),
                      );
                    }
                  },
                  splashColor: AppTheme.primary.withAlpha(15),
                  highlightColor: Colors.transparent,
                  child: _DotNavItem(item: items[index], isActive: isActiveTab),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _DotNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;

  const _DotNavItem({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary.withAlpha(18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isActive ? item.activeIcon : item.icon,
              key: ValueKey(isActive),
              size: 22,
              color: isActive ? AppTheme.primary : AppTheme.onSurfaceMuted,
            ),
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? AppTheme.primary : AppTheme.onSurfaceMuted,
          ),
          child: Text(item.label),
        ),
      ],
    );
  }
}

class _TabletRail extends StatelessWidget {
  final int currentIndex;
  final String userRole;
  final String userName;
  final String userId;
  final bool isActive;
  final String storeId;
  final String storeName;

  const _TabletRail({
    required this.currentIndex,
    required this.userRole,
    this.userName = '',
    this.userId = '',
    this.isActive = true,
    this.storeId = '',
    this.storeName = '',
  });

  @override
  Widget build(BuildContext context) {
    final items = AppNavigation._getNavItems(userRole);
    return NavigationRail(
      backgroundColor: AppTheme.surface,
      selectedIndex: currentIndex,
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: AppTheme.primary.withAlpha(18),
      selectedIconTheme: const IconThemeData(color: AppTheme.primary, size: 22),
      unselectedIconTheme: const IconThemeData(
        color: AppTheme.onSurfaceMuted,
        size: 22,
      ),
      selectedLabelTextStyle: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.primary,
      ),
      unselectedLabelTextStyle: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppTheme.onSurfaceMuted,
      ),
      onDestinationSelected: (index) {
        if (index != currentIndex) {
          if (!PermissionService.instance.canPerformAnyAction) return;
          Navigator.pushReplacementNamed(
            context,
            items[index].route,
            arguments: AppNavigation._routeArgs(
              userRole,
              userName: userName,
              userId: userId,
              isActive: isActive,
              storeId: storeId,
              storeName: storeName,
            ),
          );
        }
      },
      destinations: items
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }
}
