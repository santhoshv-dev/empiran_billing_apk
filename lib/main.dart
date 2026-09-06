import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_store.dart';
import 'core/theme/app_theme.dart';
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
      Future.delayed(const Duration(milliseconds: 1200)),
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
    final defaultAdmin =
        clean == 'empirantraders' && password.trim() == '123456';
    final validUser = store.users.any(
      (u) =>
          (u['username']?.toLowerCase() == clean ||
              u['email']?.toLowerCase() == clean) &&
          u['password'] == password.trim(),
    );
    if (!defaultAdmin && !validUser) {
      await store.remoteLogin(clean, password.trim());
    }
    final p = await SharedPreferences.getInstance();
    if (defaultAdmin || validUser) {
      await p.setString('sessionToken', 'local-admin-session');
      await p.setString(
        'sessionExpiry',
        DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      );
    }
    setState(() => authenticated = true);
  }

  Future<void> register(String name, String email, String password) async {
    await store.remoteRegister(name, email, password);
    setState(() => authenticated = true);
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('sessionToken');
    await p.remove('sessionExpiry');
    await store.disconnectApi();
    setState(() => authenticated = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Empiran Traders',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
    home: loading
        ? const SplashScreen()
        : authenticated
        ? SuiteShell(store: store, onLogout: logout)
        : LoginScreen(onLogin: login, onRegister: register),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff032f5f), Color(0xff087fbd)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(
                        alpha: .25 + c.value * .5,
                      ),
                      blurRadius: 20 + c.value * 25,
                      spreadRadius: c.value * 7,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  size: 62,
                  color: Color(0xff075fae),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'EMPIRAN TRADERS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  value: c.value,
                  color: Colors.orangeAccent,
                  backgroundColor: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
  });
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
  @override
  void dispose() {
    u.dispose();
    p.dispose();
    name.dispose();
    super.dispose();
  }

  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundImage: AssetImage(
                      'assets/images/empiran_traders_logo.png',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'EMPIRAN TRADERS',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to manage billing and inventory',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (registering) ...[
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: u,
                    keyboardType: registering
                        ? TextInputType.emailAddress
                        : null,
                    decoration: InputDecoration(
                      labelText: registering
                          ? 'Email'
                          : 'Username or API email',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: p,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        tooltip: showPassword
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              if (registering) {
                                await widget.onRegister(
                                  name.text.trim(),
                                  u.text.trim(),
                                  p.text,
                                );
                              } else {
                                await widget.onLogin(u.text.trim(), p.text);
                              }
                            } catch (e) {
                              setState(
                                () => error = e.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(registering ? 'Create API account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            registering = !registering;
                            error = null;
                            u.text = registering ? '' : 'empirantraders';
                            p.text = registering ? '' : '123456';
                          }),
                    child: Text(
                      registering
                          ? 'Already have an account? Sign in'
                          : 'Create a cloud account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
