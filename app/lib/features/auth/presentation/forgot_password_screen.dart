import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'auth_screens.dart';

/// Two-step reset (M1 spec D2): request a 6-digit code, then enter the
/// code plus a new password. The request step shows the same message
/// whether or not the account exists — no account enumeration.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  bool _codeSent = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_email.text);
    // Deliberately advance regardless of whether the account exists.
    if (mounted) setState(() => _codeSent = true);
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final ok =
        await ref.read(authControllerProvider.notifier).confirmPasswordReset(
              email: _email.text,
              code: _code.text,
              newPassword: _newPassword.text,
            );
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/auth/sign-in')),
        title: const Text('Reset password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 16),
                if (_codeSent && auth.hasError) ...[
                  AuthErrorBanner(message: auth.error.toString()),
                  const SizedBox(height: 16),
                ],
                if (!_codeSent) ...[
                  Text(
                    'Enter your email and we\'ll send a 6-digit code.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _email,
                    validator: validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _requestCode,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send code'),
                  ),
                ] else ...[
                  Text(
                    'If an account exists for ${_email.text.trim()}, '
                    'a code is on its way. Enter it below with your '
                    'new password.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _code,
                    validator: validateResetCode,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: '6-digit code'),
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _newPassword,
                    label: 'New password',
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Set new password'),
                  ),
                  TextButton(
                    onPressed: auth.isLoading ? null : _requestCode,
                    child: const Text('Resend code'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
