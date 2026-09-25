import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/school_brand.dart';
import '../../domain/account_identifier.dart';
import '../controllers/auth_controller.dart';

enum _RecoveryStep { identifier, code, complete }

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({required this.controller, super.key});

  final AuthController controller;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  _RecoveryStep _step = _RecoveryStep.identifier;
  bool _isWorking = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _errorMessage;
  String? _deliveryMessage;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: SchoolBrandLogo(size: 72)),
            const SizedBox(height: 18),
            Text(
              switch (_step) {
                _RecoveryStep.identifier => 'Find your account',
                _RecoveryStep.code => 'Enter your reset code',
                _RecoveryStep.complete => 'Password updated',
              },
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              switch (_step) {
                _RecoveryStep.identifier => 'Use the email address or Philippine mobile number connected to your QRDify account.',
                _RecoveryStep.code =>
                  _deliveryMessage ??
                      'Enter the six-digit code sent to your account contact.',
                _RecoveryStep.complete =>
                  'You can now sign in with your new password.',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _step == _RecoveryStep.complete
                    ? _CompleteView(onDone: () => Navigator.pop(context))
                    : Form(
                        key: _formKey,
                        child: _step == _RecoveryStep.identifier
                            ? _identifierForm()
                            : _codeForm(),
                      ),
              ),
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: message),
            ],
          ],
        ),
      ),
    );
  }

  Widget _identifierForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('EMAIL OR MOBILE NUMBER', style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: _identifierController,
          enabled: !_isWorking,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _requestCode(),
          decoration: const InputDecoration(
            hintText: 'parent@email.com or 09XXXXXXXXX',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
          validator: validateAccountIdentifier,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _isWorking ? null : _requestCode,
          icon: _workingIcon(Icons.outgoing_mail),
          label: const Text('Send reset code'),
        ),
      ],
    );
  }

  Widget _codeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('VERIFICATION CODE', style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: _codeController,
          enabled: !_isWorking,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: '6-digit code',
            prefixIcon: Icon(Icons.verified_user_outlined),
            counterText: '',
          ),
          validator: (value) => RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
              ? null
              : 'Enter the six-digit code.',
        ),
        const SizedBox(height: 16),
        const Text('NEW PASSWORD', style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          enabled: !_isWorking,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'At least 8 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) =>
              (value?.length ?? 0) < 8 ? 'Use at least 8 characters.' : null,
        ),
        const SizedBox(height: 16),
        const Text('CONFIRM PASSWORD', style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmationController,
          enabled: !_isWorking,
          obscureText: _obscureConfirmation,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _resetPassword(),
          decoration: InputDecoration(
            hintText: 'Repeat your new password',
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            suffixIcon: IconButton(
              tooltip: _obscureConfirmation
                  ? 'Show password confirmation'
                  : 'Hide password confirmation',
              onPressed: () =>
                  setState(() => _obscureConfirmation = !_obscureConfirmation),
              icon: Icon(
                _obscureConfirmation
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) => value != _passwordController.text
              ? 'Passwords do not match.'
              : null,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _isWorking ? null : _resetPassword,
          icon: _workingIcon(Icons.password_rounded),
          label: const Text('Update password'),
        ),
        TextButton(
          onPressed: _isWorking || _resendSeconds > 0 ? null : _resendCode,
          child: Text(
            _resendSeconds > 0
                ? 'Send another code in ${_resendSeconds}s'
                : 'Send another code',
          ),
        ),
        TextButton(
          onPressed: _isWorking ? null : _useDifferentAccount,
          child: const Text('Use a different email or mobile number'),
        ),
      ],
    );
  }

  Widget _workingIcon(IconData icon) => _isWorking
      ? const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : Icon(icon);

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _sendCode(moveToCodeStep: true);
  }

  Future<void> _resendCode() => _sendCode(moveToCodeStep: false);

  Future<void> _sendCode({required bool moveToCodeStep}) async {
    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.controller.requestPasswordReset(
        identifier: _identifierController.text,
      );
      if (!mounted) return;
      setState(() {
        _deliveryMessage = result.message;
        if (moveToCodeStep) _step = _RecoveryStep.code;
      });
      _startResendTimer(result.resendIn);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _message(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });
    try {
      await widget.controller.resetPassword(
        identifier: _identifierController.text,
        code: _codeController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      _codeController.clear();
      _passwordController.clear();
      _confirmationController.clear();
      _resendTimer?.cancel();
      setState(() => _step = _RecoveryStep.complete);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _message(error));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _startResendTimer(Duration duration) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = duration.inSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  void _useDifferentAccount() {
    _resendTimer?.cancel();
    _codeController.clear();
    _passwordController.clear();
    _confirmationController.clear();
    setState(() {
      _step = _RecoveryStep.identifier;
      _errorMessage = null;
      _deliveryMessage = null;
      _resendSeconds = 0;
    });
  }

  String _message(Object error) => switch (error) {
    ApiException exception => exception.message,
    FormatException _ => 'QRDify returned an invalid response.',
    _ => 'Unable to reset your password. Please try again.',
  };
}

class _CompleteView extends StatelessWidget {
  const _CompleteView({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFE8F8EF),
          child: Icon(Icons.check_rounded, color: AppColors.success, size: 38),
        ),
        const SizedBox(height: 18),
        const Text(
          'Your old sessions have been signed out for security.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onDone,
            child: const Text('Return to sign in'),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  color: AppColors.ink,
  fontSize: 12,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.4,
);
