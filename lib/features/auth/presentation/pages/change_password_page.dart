import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empiran_components.dart';
import '../../data/repositories/auth_repository.dart';

enum PasswordAction { forgot, reset, update }

class ChangePasswordPage extends StatefulWidget {
  final bool isForgot;
  final String? token;

  const ChangePasswordPage({
    super.key,
    this.isForgot = false,
    this.token,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({
    super.key,
    this.isForgot = false,
    this.onSuccessAction,
    this.successActionLabel,
  });

  final bool isForgot;
  final VoidCallback? onSuccessAction;
  final String? successActionLabel;

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    final repo = context.read<AuthRepository>();

    try {
      if (widget.isForgot) {
        await repo.forgotPassword(_emailController.text.trim());
        _message = 'A temporary password has been sent to your email.\n\nLog in with it, then go to Settings → Change Password to set a new password.';
      } else {
        await repo.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
        _message = 'Password updated successfully!';
      }
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e is DioException ? e.message ?? '$e' : '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmpiranCard(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Icon(
                Icons.lock_reset_rounded,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            if (!_success) ...[
              if (widget.isForgot)
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Registered Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) => value == null || !value.contains('@')
                      ? 'Enter your registered email.'
                      : null,
                )
              else ...[
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter current password.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  validator: (value) =>
                      value != null && value.length >= 6 ? null : 'Minimum 6 characters.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  validator: (value) => value != _newPasswordController.text
                      ? 'Passwords do not match.'
                      : null,
                ),
              ],
              const SizedBox(height: 24),
              if (_message != null) ...[
                Text(
                  _message!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
                const SizedBox(height: 16),
              ],
              EmpiranButton(
                label: widget.isForgot ? 'Send Instructions' : 'Update Password',
                isLoading: _busy,
                onPressed: _submit,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Text(
                  _message ?? 'Request succeeded.',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              EmpiranButton(
                label: widget.successActionLabel ?? 'Back to Login',
                onPressed: widget.onSuccessAction ?? () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  @override
  Widget build(BuildContext context) {
    final title = widget.isForgot ? 'Forgot Password' : 'Change Password';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ChangePasswordForm(isForgot: widget.isForgot),
          ),
        ),
      ),
    );
  }
}
