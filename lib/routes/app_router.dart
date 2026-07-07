import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/recurrences/recurrences_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shared_budgets/shared_budget_detail_screen.dart';
import '../screens/shared_budgets/shared_budgets_screen.dart';
import '../screens/statistics/statistics_screen.dart';
import '../screens/transactions/transactions_screen.dart';
import '../screens/budgets/budgets_screen.dart';
import '../screens/shell/main_shell.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/statistics', builder: (context, state) => const StatisticsScreen()),
      GoRoute(path: '/recurrences', builder: (context, state) => const RecurrencesScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/shared-budgets', builder: (context, state) => const SharedBudgetsScreen()),
      GoRoute(
        path: '/shared-budgets/:id',
        builder: (context, state) => SharedBudgetDetailScreen(
          budgetId: state.pathParameters['id']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/budgets', builder: (context, state) => const BudgetsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}