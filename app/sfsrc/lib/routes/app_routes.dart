import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../presentation/alerts_screen/alerts_screen.dart';
import '../presentation/groups_screen/groups_screen.dart';
import '../presentation/join_invitation_screen/join_invitation_screen.dart';
import '../presentation/live_map_screen/live_map_screen.dart';
import '../presentation/onboarding_screen/onboarding_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../widgets/app_scaffold.dart';

class AppRoutes {
  static const String initial = '/';
  static const String onboardingScreen = '/onboarding-screen';
  static const String signUpLoginScreen = '/sign-up-login-screen';
  static const String liveMapScreen = '/live-map-screen';
  static const String groupsScreen = '/groups-screen';
  static const String profileScreen = '/profile-screen';
  static const String alertsScreen = '/alerts-screen';
  static const String joinInvitation = '/join/:token';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  redirect: (context, state) {
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    final isOnAuthRoute = state.matchedLocation == AppRoutes.signUpLoginScreen;
    final isOnOnboarding =
        state.matchedLocation == AppRoutes.initial ||
        state.matchedLocation == AppRoutes.onboardingScreen;
    // Allow /join/:token to pass through regardless of auth state
    final isJoinRoute = state.matchedLocation.startsWith('/join/');

    if (isJoinRoute) return null;

    // If authenticated and on auth/onboarding route, go to map
    if (isAuthenticated && (isOnAuthRoute || isOnOnboarding)) {
      return AppRoutes.liveMapScreen;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.initial,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboardingScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
    GoRoute(
      path: AppRoutes.signUpLoginScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SignUpLoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset =
              Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ),
    // /join/:token — invitation acceptance (works for both auth and unauth users)
    GoRoute(
      path: '/join/:token',
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: JoinInvitationScreen(token: token),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        );
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.liveMapScreen,
              builder: (context, state) => const LiveMapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.groupsScreen,
              builder: (context, state) => const GroupsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.alertsScreen,
              builder: (context, state) => const AlertsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profileScreen,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
