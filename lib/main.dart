import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/api_client.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/change_password_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/invoices/data/repositories/invoices_repository.dart';
import 'features/invoices/presentation/bloc/invoices_bloc.dart';
import 'features/invoices/presentation/bloc/invoices_event.dart';
import 'features/parties/data/repositories/parties_repository.dart';
import 'features/parties/presentation/bloc/parties_bloc.dart';
import 'features/parties/presentation/bloc/parties_event.dart';
import 'features/products/data/repositories/products_repository.dart';
import 'features/products/presentation/bloc/products_bloc.dart';
import 'features/products/presentation/bloc/products_event.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_event.dart';
import 'features/shell/presentation/pages/shell_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();

  runApp(EmpiranApp(apiClient: apiClient));
}

class EmpiranApp extends StatelessWidget {
  final ApiClient apiClient;

  const EmpiranApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: apiClient),
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepository(apiClient: apiClient),
        ),
        RepositoryProvider<SettingsRepository>(
          create: (context) => SettingsRepository(apiClient: apiClient),
        ),
        RepositoryProvider<ProductsRepository>(
          create: (context) => ProductsRepository(apiClient: apiClient),
        ),
        RepositoryProvider<PartiesRepository>(
          create: (context) => PartiesRepository(apiClient: apiClient),
        ),
        RepositoryProvider<InvoicesRepository>(
          create: (context) => InvoicesRepository(apiClient: apiClient),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            )..add(const AuthCheckRequested()),
          ),
          BlocProvider<SettingsBloc>(
            create: (context) => SettingsBloc(
              settingsRepository: context.read<SettingsRepository>(),
            )..add(const LoadSettingsRequested()),
          ),
          BlocProvider<ProductsBloc>(
            create: (context) => ProductsBloc(
              productsRepository: context.read<ProductsRepository>(),
            )..add(const LoadProductsRequested()),
          ),
          BlocProvider<PartiesBloc>(
            create: (context) => PartiesBloc(
              partiesRepository: context.read<PartiesRepository>(),
            )..add(const LoadPartiesRequested()),
          ),
          BlocProvider<InvoicesBloc>(
            create: (context) => InvoicesBloc(
              invoicesRepository: context.read<InvoicesRepository>(),
            )..add(const LoadInvoicesRequested()),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Billing App',
          theme: AppTheme.theme,
          darkTheme: AppTheme.theme,
          themeMode: ThemeMode.light,
          onGenerateRoute: (settings) {
            final uri = Uri.tryParse(settings.name ?? '');
            if (uri?.path == AppRoutePaths.resetPassword) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => ChangePasswordPage(
                  isForgot: false,
                  token: uri!.queryParameters['token'],
                ),
              );
            }
            return null;
          },
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthInitial || state is AuthLoading) {
                return const SplashScreen();
              }
              if (state is AuthAuthenticated) {
                return const ShellPage();
              }
              return const LoginPage();
            },
          ),
        ),
      ),
    );
  }
}

/// Splash Screen: Airy Ice-Blue Canvas with Floating Logo and Shimmer
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: AppColors.primary
                        .withValues(alpha: 0.35 + _ctrl.value * 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: 0.15 + _ctrl.value * 0.2),
                      blurRadius: 28 + _ctrl.value * 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Image.asset(
                  'assets/images/empiran_traders_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.account_balance_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Billing App',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Billing & Business Management',
                style: TextStyle(
                  color: AppColors.lightTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 160,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _ctrl.value,
                    color: AppColors.primary,
                    backgroundColor: AppColors.lightSurfaceContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
