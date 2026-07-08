import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kashflo_mobile/providers/shared_budget_detail_provider.dart';
import 'package:kashflo_mobile/providers/shared_budgets_provider.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/recurrence_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/currency_provider.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('fr_FR', null);
  runApp(const KashFloApp());
}

class KashFloApp extends StatelessWidget {
  const KashFloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. AuthProvider — ne dépend de rien
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // 2. Providers dépendant seulement de AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, auth, previous) => previous!..updateUser(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, BudgetProvider>(
          create: (_) => BudgetProvider(),
          update: (_, auth, previous) => previous!..updateUser(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, RecurrenceProvider>(
          create: (_) => RecurrenceProvider(),
          update: (_, auth, previous) => previous!..updateUser(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, UserProfileProvider>(
          create: (_) => UserProfileProvider(),
          update: (_, auth, previous) => previous!..updateUser(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SharedBudgetsProvider>(
          create: (_) => SharedBudgetsProvider(),
          update: (_, auth, previous) => previous!..updateUser(auth.user?.uid),
        ),

        // 3. CurrencyProvider — doit venir APRÈS UserProfileProvider,
        //    car il dépend de AuthProvider ET UserProfileProvider
        ChangeNotifierProxyProvider2<AuthProvider, UserProfileProvider, CurrencyProvider>(
          create: (_) => CurrencyProvider(),
          update: (_, auth, userProfile, previous) {
            final provider = previous!;
            if (auth.user != null && userProfile.profile != null) {
              provider.updateCurrency(userProfile.profile!.currency);
            } else if (auth.user == null) {
              provider.updateCurrency(null);
            }
            return provider;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'KashFlo',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
        ),
        routerConfig: AppRouter.router,
      ),
    );
  }
}