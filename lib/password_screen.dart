import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'data/remote/api_client.dart';

enum PasswordAction { forgot, reset, update }

class PasswordScreen extends StatefulWidget {
  const PasswordScreen(
      {super.key, required this.api, required this.action, this.token});
  final ApiClient api;
  final PasswordAction action;
  final String? token;
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final current = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  String? message;
  bool success = false;

  @override
  void dispose() {
    for (final controller in [email, current, password, confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final Response<dynamic> result;
      switch (widget.action) {
        case PasswordAction.forgot:
          result = await widget.api.dio
              .post('auth/forgot-password', data: {'email': email.text.trim()});
        case PasswordAction.reset:
          result = await widget.api.dio.post('auth/reset-password',
              data: {'token': widget.token, 'newPassword': password.text});
        case PasswordAction.update:
          result = await widget.api.dio.post('users/update-password', data: {
            'currentPassword': current.text,
            'newPassword': password.text
          });
      }
      if (!mounted) return;
      setState(() {
        success = true;
        message = '${result.data['message']}';
      });
    } on DioException catch (error) {
      if (mounted)
        setState(() =>
            message = error.message ?? 'The request failed. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.action) {
      PasswordAction.forgot => 'Forgot password',
      PasswordAction.reset => 'Reset password',
      PasswordAction.update => 'Update password',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset_rounded, size: 64),
                    const SizedBox(height: 24),
                    if (!success) ...[
                      if (widget.action == PasswordAction.forgot)
                        TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                                labelText: 'Registered email'),
                            validator: (value) =>
                                value == null || !value.contains('@')
                                    ? 'Enter your email address.'
                                    : null),
                      if (widget.action == PasswordAction.update) ...[
                        TextFormField(
                            controller: current,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'Current password'),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter your current password.'
                                : null),
                        const SizedBox(height: 16),
                      ],
                      if (widget.action != PasswordAction.forgot) ...[
                        TextFormField(
                            controller: password,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'New password'),
                            validator: (value) => value == null ||
                                    value.length < 8 ||
                                    value.length > 128
                                ? 'Use 8 to 128 characters.'
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: confirm,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'Confirm password'),
                            validator: (value) => value != password.text
                                ? 'Passwords must match.'
                                : null),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: busy ? null : submit,
                          child: Text(busy ? 'Please wait...' : title)),
                    ],
                    if (message != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(message!, semanticsLabel: message)),
                    if (success)
                      TextButton(
                          onPressed: () => Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                          child: const Text('Done')),
                  ]),
            )),
      )),
    );
  }
}
