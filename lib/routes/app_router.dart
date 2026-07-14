import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/shared_budget_detail_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/budgets/budget_detail_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/settings/categories_screen.dart';
import '../screens/recurrences/recurrences_screen.dart';
import '../screens/savings/savings_screen.dart';
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
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final onAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/statistics',
        builder: (context, state) => const StatisticsScreen(),
      ),
      GoRoute(
        path: '/recurrences',
        builder: (context, state) => const RecurrencesScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/budgets/:id',
        builder: (context, state) {
          final budgetId = state.pathParameters['id']!;
          return BudgetDetailScreen(budgetId: budgetId);
        },
      ),
      GoRoute(
        path: '/shared-budgets',
        builder: (context, state) => const SharedBudgetsScreen(),
      ),
      GoRoute(
        path: '/shared-budgets/:id',
        builder: (context, state) {
          final budgetId = state.pathParameters['id']!;
          return ChangeNotifierProvider(
            create: (_) => SharedBudgetDetailProvider()..listen(budgetId),
            child: SharedBudgetDetailScreen(budgetId: budgetId),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                builder: (context, state) => const BudgetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/savings',
                builder: (context, state) => const SavingsScreen(),
              ),
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
