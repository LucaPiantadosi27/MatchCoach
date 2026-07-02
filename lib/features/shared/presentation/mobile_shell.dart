import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavagna_tattica/core/theme.dart';
import 'package:lavagna_tattica/features/auth/providers/auth_providers.dart';

class MobileShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const MobileShell({
    super.key,
    required this.child,
    required this.state,
  });

  static const double _mobileBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _mobileBreakpoint;
    final currentPath = state.matchedLocation;

    if (isMobile) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _indexForPath(currentPath),
          onDestinationSelected: (index) {
            final path = _pathForIndex(index);
            if (path != currentPath) context.go(path);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 22),
              selectedIcon: Icon(Icons.home_rounded, size: 22),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_soccer_outlined, size: 22),
              selectedIcon: Icon(Icons.sports_soccer_rounded, size: 22),
              label: 'Lavagna',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined, size: 22),
              selectedIcon: Icon(Icons.folder_rounded, size: 22),
              label: 'Schemi',
            ),
            NavigationDestination(
              icon: Icon(Icons.videocam_outlined, size: 22),
              selectedIcon: Icon(Icons.videocam_rounded, size: 22),
              label: 'Video AI',
            ),
          ],
        ),
      );
    }

    // ── Desktop: sidebar + content ─────────────────────────────
    final hideSidebar = currentPath.startsWith('/board');
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: hideSidebar
          ? child
          : Row(
              children: [
                _AppSidebar(currentPath: currentPath),
                const VerticalDivider(width: 1, thickness: 1, color: AppTheme.sidebarBorderColor),
                Expanded(child: child),
              ],
            ),
    );
  }

  static int _indexForPath(String path) {
    if (path.startsWith('/home')) return 0;
    if (path.startsWith('/board')) return 1;
    if (path.startsWith('/schemes') || path.startsWith('/recording')) return 2;
    if (path.startsWith('/video')) return 3;
    return 0;
  }

  static String _pathForIndex(int index) {
    switch (index) {
      case 0: return '/home';
      case 1: return '/board';
      case 2: return '/schemes';
      case 3: return '/video';
      default: return '/home';
    }
  }
}

// ── Desktop Sidebar ───────────────────────────────────────────────
class _AppSidebar extends ConsumerWidget {
  final String currentPath;
  const _AppSidebar({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: AppTheme.sidebarGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header – matches AppBar height ───────────────────
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.sidebarBorderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentGreen, AppTheme.accentGreenDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.sports_soccer_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MatchCoach-AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Nav items ────────────────────────────────────────
          _SidebarItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
            path: '/home',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.sports_soccer_outlined,
            activeIcon: Icons.sports_soccer_rounded,
            label: 'Lavagna',
            path: '/board',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder_rounded,
            label: 'Schemi',
            path: '/schemes',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.videocam_outlined,
            activeIcon: Icons.videocam_rounded,
            label: 'Video AI',
            path: '/video',
            currentPath: currentPath,
          ),
          _SidebarItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            label: 'Statistiche',
            path: '/usage',
            currentPath: currentPath,
          ),

          const Spacer(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: AppTheme.sidebarBorderColor, height: 1),
          ),
          // ── Logout ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final authRepo = ref.read(authRepositoryProvider);
                  await authRepo.signOut();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: AppTheme.textMuted),
                      SizedBox(width: 10),
                      Text(
                        'Esci',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final String currentPath;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
    required this.currentPath,
  });

  bool get _isActive => currentPath.startsWith(path);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (!_isActive) context.go(path);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _isActive
                  ? const Color(0xFF9575CD).withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: _isActive
                  ? Border.all(color: const Color(0xFF9575CD).withValues(alpha: 0.3), width: 1)
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _isActive ? activeIcon : icon,
                  size: 18,
                  color: _isActive
                      ? const Color(0xFF9575CD)
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _isActive ? FontWeight.w600 : FontWeight.w400,
                    color: _isActive
                        ? const Color(0xFF9575CD)
                        : AppTheme.textSecondary,
                  ),
                ),
                if (_isActive) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9575CD),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
