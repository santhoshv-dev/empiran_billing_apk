import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_store.dart';
import 'core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'suite.dart';
import 'password_screen.dart';

/// The public entry point is sign-in only; administrators manage accounts.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store, required this.onLogin});
  final AppStore store;
  final Future<void> Function(String, String) onLogin;
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool showPassword = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onLogin(username.text.trim(), password.text);
    } catch (exception) {
      if (mounted) {
        setState(() => error = exception is DioException
            ? exception.message ?? 'Unable to sign in. Please try again.'
            : 'Unable to sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AutofillGroup(
              child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                gradient: AppGradients.primary,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: AppShadows.soft),
                            child: const Icon(Icons.receipt_long_rounded,
                                color: Colors.white, size: 42),
                          )),
                      const SizedBox(height: 24),
                      Text('Billing App',
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('Welcome back. Let’s get to business.',
                          style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 32),
                      Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Sign in',
                                        style: theme.textTheme.headlineSmall),
                                    const SizedBox(height: 24),
                                    TextFormField(
                                        controller: username,
                                        enabled: !busy,
                                        autofillHints: const [
                                          AutofillHints.username
                                        ],
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                            labelText: 'Username or email',
                                            prefixIcon: Icon(
                                                Icons.person_outline_rounded)),
                                        validator: (value) => value == null ||
                                                value.trim().isEmpty
                                            ? 'Enter your username or email.'
                                            : null),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        controller: password,
                                        enabled: !busy,
                                        obscureText: !showPassword,
                                        autofillHints: const [
                                          AutofillHints.password
                                        ],
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => signIn(),
                                        decoration: InputDecoration(
                                            labelText: 'Password',
                                            prefixIcon: const Icon(
                                                Icons.lock_outline_rounded),
                                            suffixIcon: IconButton(
                                                tooltip: showPassword
                                                    ? 'Hide password'
                                                    : 'Show password',
                                                onPressed: () => setState(() =>
                                                    showPassword =
                                                        !showPassword),
                                                icon: Icon(showPassword
                                                    ? Icons
                                                        .visibility_off_outlined
                                                    : Icons
                                                        .visibility_outlined))),
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                                ? 'Enter your password.'
                                                : null),
                                    Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => Navigator.of(context)
                                                    .push(MaterialPageRoute<
                                                            void>(
                                                        builder: (_) =>
                                                            PasswordScreen(
                                                                api: widget
                                                                    .store.api,
                                                                action:
                                                                    PasswordAction
                                                                        .forgot))),
                                            child: const Text(
                                                'Forgot password?'))),
                                    if (error != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 16),
                                          child: Semantics(
                                              liveRegion: true,
                                              child: Text(error!,
                                                  style: TextStyle(
                                                      color: colors.error)))),
                                    FilledButton(
                                        onPressed: busy ? null : signIn,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            child: Text(busy
                                                ? 'Signing in...'
                                                : 'Sign in'))),
                                  ]))),
                      const SizedBox(height: 24),
                      Text('Need an account? Contact your administrator.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall),
                    ],
                  ))),
        ),
      ))),
    );
  }
}

void main() => runApp(const EmpiranApp());

class EmpiranApp extends StatefulWidget {
  const EmpiranApp({super.key});
  @override
  State<EmpiranApp> createState() => _EmpiranAppState();
}

class _EmpiranAppState extends State<EmpiranApp> {
  final store = AppStore();
  bool loading = true, authenticated = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_refreshTheme);
    _start();
  }

  void _refreshTheme() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_refreshTheme);
    store.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await Future.wait([
      store.load(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    final p = await SharedPreferences.getInstance();
    final expiry = DateTime.tryParse(p.getString('sessionExpiry') ?? '');
    if (mounted) {
      setState(() {
        authenticated = store.remoteMode &&
            store.currentUser != null &&
            (expiry?.isAfter(DateTime.now()) ?? false);
        loading = false;
      });
    }
  }

  Future<void> login(String username, String password) async {
    final clean = username.trim().toLowerCase();
    await store.remoteLogin(clean, password);
    if (mounted) setState(() => authenticated = true);
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('sessionToken');
    await p.remove('sessionExpiry');
    await p.remove('currentUser');
    store.currentUser = null;
    await store.disconnectApi();
    setState(() => authenticated = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Billing App',
        theme: AppTheme.theme,
        darkTheme: AppTheme.theme,
        themeMode: ThemeMode.light,
        onGenerateRoute: (settings) {
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri?.path == '/reset-password') {
            return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => PasswordScreen(
                    api: store.api,
                    action: PasswordAction.reset,
                    token: uri!.queryParameters['token']));
          }
          return null;
        },
        home: loading
            ? const SplashScreen()
            : authenticated
                ? SuiteShell(store: store, onLogout: logout)
                : LoginScreen(store: store, onLogin: login),
      );
}

/// SWeShare-Inspired Splash Screen: Airy Ice-Blue Canvas with Floating Logo and Shimmer
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                  color: isDark ? AppColors.darkSurface : Colors.white,
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
              Text(
                'Billing & Business Management',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
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
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.lightSurfaceContainer,
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
