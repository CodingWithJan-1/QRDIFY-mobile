import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/school_brand.dart';
import '../../domain/parent_enrollment_repository.dart';
import '../controllers/parent_enrollment_controller.dart';

class ParentEnrollmentPage extends StatefulWidget {
  const ParentEnrollmentPage({
    required this.repository,
    this.accessToken,
    super.key,
  });

  final ParentEnrollmentRepository repository;
  final String? accessToken;

  @override
  State<ParentEnrollmentPage> createState() => _ParentEnrollmentPageState();
}

class _ParentEnrollmentPageState extends State<ParentEnrollmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final ParentEnrollmentController _controller;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _controller = ParentEnrollmentController(
      widget.repository,
      accessToken: widget.accessToken,
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent invitation')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.step == ParentEnrollmentStep.complete) {
            return _CompleteView(existingParent: _controller.isExistingParent);
          }
          if (_controller.requiresSignIn) {
            return _ExistingParentView(
              onReturnToSignIn: () => Navigator.of(context).pop(),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(child: SchoolBrandLogo(size: 72)),
              const SizedBox(height: 18),
              Text(
                _controller.step == ParentEnrollmentStep.invitation
                    ? 'Connect your approved invitation'
                    : 'Verify your email',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _controller.step == ParentEnrollmentStep.invitation
                    ? 'Enter the invitation token sent by the school. Each invitation connects one child.'
                    : 'Enter the six-digit code sent to the approved email address.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: _controller.step == ParentEnrollmentStep.invitation
                        ? _InvitationForm(
                            tokenController: _tokenController,
                            isWorking: _controller.isWorking,
                            onSubmit: _requestCode,
                          )
                        : _VerificationForm(
                            codeController: _codeController,
                            nameController: _nameController,
                            passwordController: _passwordController,
                            existingParent: _controller.isExistingParent,
                            isWorking: _controller.isWorking,
                            obscurePassword: _obscurePassword,
                            onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onSubmit: _accept,
                            onStartOver: _controller.startOver,
                          ),
                  ),
                ),
              ),
              if (_controller.errorMessage case final message?) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: message),
              ],
              const SizedBox(height: 16),
              const Text(
                'A token is valid only after the school approves the Parent-to-Student relationship. QRDify never links children by matching a surname, phone number, or email address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final requested = await _controller.requestCode(_tokenController.text);
    if (!requested || !mounted) return;

    Timer? autoDismissTimer;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          autoDismissTimer ??= Timer(const Duration(seconds: 3), () {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          });

          return AlertDialog(
            icon: const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFE8F8EF),
              child: Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.success,
                size: 30,
              ),
            ),
            title: const Text(
              'Verification code sent',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Open Gmail or your email inbox and enter the six-digit code sent to the approved address. Check Spam if it does not arrive.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    } finally {
      autoDismissTimer?.cancel();
    }
  }

  Future<void> _accept() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _controller.accept(
      code: _codeController.text,
      name: _nameController.text,
      password: _passwordController.text,
    );
  }
}

class _InvitationForm extends StatelessWidget {
  const _InvitationForm({
    required this.tokenController,
    required this.isWorking,
    required this.onSubmit,
  });

  final TextEditingController tokenController;
  final bool isWorking;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('INVITATION TOKEN', style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: tokenController,
          enabled: !isWorking,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            hintText: 'Paste the token from the school email',
            prefixIcon: Icon(Icons.key_outlined),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter your invitation token.'
              : null,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: isWorking ? null : onSubmit,
          icon: isWorking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.mark_email_unread_outlined),
          label: const Text('Send verification code'),
        ),
      ],
    );
  }
}

class _VerificationForm extends StatelessWidget {
  const _VerificationForm({
    required this.codeController,
    required this.nameController,
    required this.passwordController,
    required this.existingParent,
    required this.isWorking,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onStartOver,
  });

  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final bool existingParent;
  final bool isWorking;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('VERIFICATION CODE', style: _labelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: codeController,
          enabled: !isWorking,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textInputAction: existingParent
              ? TextInputAction.done
              : TextInputAction.next,
          decoration: const InputDecoration(
            hintText: '6-digit code',
            prefixIcon: Icon(Icons.verified_user_outlined),
            counterText: '',
          ),
          validator: (value) =>
              !RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
              ? 'Enter the six-digit code.'
              : null,
        ),
        if (!existingParent) ...[
          const SizedBox(height: 16),
          const Text('YOUR NAME', style: _labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameController,
            enabled: !isWorking,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Parent or guardian name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter your name.'
                : null,
          ),
          const SizedBox(height: 16),
          const Text('CREATE PASSWORD', style: _labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: passwordController,
            enabled: !isWorking,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'At least 12 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: obscurePassword ? 'Show password' : 'Hide password',
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => (value?.length ?? 0) < 12
                ? 'Use at least 12 characters.'
                : null,
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: isWorking ? null : onSubmit,
          icon: isWorking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.family_restroom_rounded),
          label: Text(
            existingParent ? 'Add linked child' : 'Create Parent account',
          ),
        ),
        TextButton(
          onPressed: isWorking ? null : onStartOver,
          child: const Text('Use a different invitation token'),
        ),
      ],
    );
  }
}

class _CompleteView extends StatelessWidget {
  const _CompleteView({required this.existingParent});

  final bool existingParent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFE8F8EF),
              child: Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              existingParent ? 'Child added' : 'Parent account created',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              existingParent
                  ? 'The approved child is now available in your Parent dashboard.'
                  : 'Your invitation was accepted. Sign in with your new Parent account.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                existingParent ? 'Return to children' : 'Return to sign in',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExistingParentView extends StatelessWidget {
  const _ExistingParentView({required this.onReturnToSignIn});

  final VoidCallback onReturnToSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: Color(0xFFE8F0FC),
                child: Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.blue,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Parent account found',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'The email approved for this invitation already belongs to a Parent account. Sign in to that account, then choose Add approved child and enter this invitation token again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 12),
              const Text(
                'If you do not recognize the account, ask the teacher to confirm the invited Parent email.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onReturnToSignIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Return to sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  color: AppColors.ink,
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.8,
);
