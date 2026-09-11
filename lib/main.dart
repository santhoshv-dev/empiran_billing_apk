import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_store.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/empiran_components.dart';
import 'core/widgets/server_config_dialog.dart';
import 'suite.dart';

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
        authenticated = expiry?.isAfter(DateTime.now()) ?? false;
        loading = false;
      });
    }
  }

  Future<void> login(String username, String password) async {
    final clean = username.trim().toLowerCase();
    final userMatch = store.users.firstWhere(
      (u) =>
          (u['username']?.toLowerCase() == clean ||
              u['email']?.toLowerCase() == clean) &&
          u['password'] == password.trim(),
      orElse: () => {},
    );

    if (userMatch.isNotEmpty) {
      store.currentUser = Map<String, String>.from(userMatch);
    } else {
      final auth = await store.remoteLogin(clean, password.trim());
      store.currentUser = {
        'name': auth['name'] ?? clean,
        'username': clean,
        'email': clean,
        'role': auth['role'] ?? 'Admin',
      };
    }

    final p = await SharedPreferences.getInstance();
    await p.setString('sessionToken', 'user-session-${store.currentUser!['username']}');
    await p.setString('currentUser', jsonEncode(store.currentUser));
    await p.setString(
      'sessionExpiry',
      DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    );
    setState(() => authenticated = true);
  }

  Future<void> register(String name, String email, String password) async {
    await store.remoteRegister(name, email, password);
    store.currentUser = {
      'name': name.trim(),
      'username': email.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'role': 'Admin',
    };
    setState(() => authenticated = true);
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
    title: 'EMPIRAN Billing & Management',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
    home: loading
        ? const SplashScreen()
        : authenticated
            ? SuiteShell(store: store, onLogout: logout)
            : LoginScreen(store: store, onLogin: login, onRegister: register),
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
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F8FE),
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
                    color: AppColors.primary.withValues(alpha: 0.35 + _ctrl.value * 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15 + _ctrl.value * 0.2),
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
                'EMPIRAN',
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
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                    backgroundColor: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFDCEAF9),
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

/// SWeShare Signature Login Screen: Two-column split layout with 3-step progress,
/// clean inputs, vibrant action button, and hero showcase.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.store,
    required this.onLogin,
    required this.onRegister,
  });
  final AppStore store;
  final Future<void> Function(String, String) onLogin;
  final Future<void> Function(String, String, String) onRegister;

  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final u = TextEditingController(text: 'empirantraders'),
      p = TextEditingController(text: '123456'),
      name = TextEditingController();
  bool busy = false, showPassword = false, registering = false;
  int currentStep = 1;
  String? error;

  @override
  void dispose() {
    u.dispose();
    p.dispose();
    name.dispose();
    super.dispose();
  }

  Widget _roleChoice(String roleName, String username, String password, Color accent) {
    final isSelected = u.text == username;
    return InkWell(
      onTap: () {
        setState(() {
          u.text = username;
          p.text = password;
          error = null;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              roleName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? accent : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final formPanel = Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 24,
        vertical: 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SWeShare Step Stepper (1)-(2)-(3)
              SWeShareStepIndicator(
                currentStep: registering ? 2 : currentStep,
                totalSteps: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Step ${registering ? 2 : currentStep}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                registering ? 'Create your account' : 'Sign in to EMPIRAN',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                registering
                    ? 'Enter your business details to setup your cloud organization.'
                    : 'Enter your credentials to access billing and management.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Quick Demo Role Switcher
              if (!registering) ...[
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Role Demo:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    _roleChoice('Admin', 'empirantraders', '123456', AppColors.primary),
                    _roleChoice('Manager', 'manager', '123456', const Color(0xFF0284C7)),
                    _roleChoice('Biller', 'biller', '123456', const Color(0xFF10B981)),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              if (registering) ...[
                EmpiranTextField(
                  controller: name,
                  label: 'Business / Organization Name',
                  hint: 'e.g. Empiran Traders',
                  prefixIcon: Icons.business_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
              ],

              // Clean Split Input (Country prefix or icon + text)
              EmpiranTextField(
                controller: u,
                label: registering ? 'Work Email' : 'Username or Email',
                hint: registering ? 'admin@empiran.com' : 'empirantraders',
                prefixWidget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 18, color: const Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
                isRequired: true,
              ),
              const SizedBox(height: 16),

              EmpiranTextField(
                controller: p,
                label: 'Password',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: !showPassword,
                isRequired: true,
                suffixIcon: IconButton(
                  tooltip: showPassword ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => showPassword = !showPassword),
                  icon: Icon(
                    showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),

              if (error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(color: AppColors.errorDark, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // SWeShare Signature Action Button with Right Arrow
              EmpiranButton(
                label: registering ? 'Create Cloud Account' : 'Verify & Sign In',
                trailingIcon: Icons.arrow_forward_rounded,
                isLoading: busy,
                height: 50,
                isFullWidth: true,
                onPressed: () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    if (registering) {
                      await widget.onRegister(name.text.trim(), u.text.trim(), p.text);
                    } else {
                      await widget.onLogin(u.text.trim(), p.text);
                    }
                  } catch (e) {
                    setState(() => error = e.toString().replaceFirst('Exception: ', ''));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            registering = !registering;
                            error = null;
                            u.text = registering ? '' : 'empirantraders';
                            p.text = registering ? '' : '123456';
                          }),
                  child: Text(
                    registering ? 'Already have an account? Sign In' : 'Need a cloud account? Register Free',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2EDF9), height: 1),
              const SizedBox(height: 16),

              // Server Configuration & Quick Mode
              ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) {
                  final url = widget.store.currentApiUrl;
                  final isLocal = url.contains('localhost') || url.contains('127.0.0.1');
                  return Center(
                    child: InkWell(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => ServerConfigDialog(store: widget.store),
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainer : AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorderStrong,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLocal ? AppColors.primary : AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isLocal ? 'Backend: Local Dev Server' : 'Backend: Cloud API',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.tune_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    // SWeShare Hero Panel (Ice-Blue gradient with illustration showcase)
    final heroPanel = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFFDCEBFA), const Color(0xFFEAF3FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x180066FF),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/images/empiran_traders_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.account_balance_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Connect and Collaborate',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Join a modern platform to automate GST billing, real-time multi-firm inventory, and cloud sync — boosting efficiency and business growth.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // SWeShare Carousel Pills Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorderStrong : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorderStrong : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 5, child: SingleChildScrollView(child: formPanel)),
                Expanded(flex: 5, child: heroPanel),
              ],
            )
          : SingleChildScrollView(child: formPanel),
    );
  }
}
