import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/routing/glass_route.dart';
import '../../core/services/fcm.dart';
import '../../core/widgets/glass_bottom_nav.dart';
import '../bookmarks/presentation/saved_screen.dart';
import '../explore/presentation/explore_screen.dart';
import '../home/presentation/home_screen.dart';
import '../notifications/presentation/notification_providers.dart';
import '../profile/presentation/profile_screen.dart';
import '../prompts/presentation/create_prompt_screen.dart';

/// Root shell: floating pill bottom nav (Home / Explore / Create / Saved /
/// Profile) over an IndexedStack so each tab keeps its own scroll position.
///
/// The Create tab *pushes* a full-screen route instead of switching tabs, so
/// the highlighted pill never moves to it.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _navIndex = 0; // which pill is highlighted (0..4, never 2)
  int _tabIndex = 0; // which of the four kept-alive tabs is visible

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    // Hydrate like/bookmark/follow sets once per session so cards render with
    // the user's real state immediately.
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      await ref.read(interactionsProvider.notifier).hydrate(uid);
    }
    // Ask for notification permission; tokens are what the notification
    // Cloud Functions push to.
    try {
      await ref.read(fcmServiceProvider).requestPermissionAndGetToken();
    } catch (_) {
      // Permission denied or no Play services — in-app notifications still work.
    }
    // Start streaming the unread badge.
    ref.invalidate(unreadCountProvider);
  }

  void _onSelect(int index) {
    switch (index) {
      case 0:
        setState(() {
          _navIndex = 0;
          _tabIndex = 0;
        });
      case 1:
        setState(() {
          _navIndex = 1;
          _tabIndex = 1;
        });
      case 2:
        Navigator.of(context).push(
          GlassPageRoute<void>(builder: (_) => const CreatePromptScreen()),
        );
      case 3:
        setState(() {
          _navIndex = 3;
          _tabIndex = 2;
        });
      case 4:
        setState(() {
          _navIndex = 4;
          _tabIndex = 3;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          HomeScreen(),
          ExploreScreen(),
          SavedScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _navIndex,
        onSelect: _onSelect,
        items: const [
          GlassNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          GlassNavItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: 'Explore',
          ),
          GlassNavItem(
            icon: Icons.add_circle_outline_rounded,
            activeIcon: Icons.add_circle_rounded,
            label: 'Create',
          ),
          GlassNavItem(
            icon: Icons.bookmark_border_rounded,
            activeIcon: Icons.bookmark_rounded,
            label: 'Saved',
          ),
          GlassNavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
