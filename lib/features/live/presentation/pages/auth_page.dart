import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/live_theme.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/session_controller.dart';

/// Sign in or create an account.
///
/// Both modes share one form: the fields a registration needs are simply
/// revealed, which keeps the transition between the two continuous rather than
/// a screen swap.
class AuthPage extends GetView<SessionController> {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: LiveColors.background,
    body: SafeArea(child: _AuthForm()),
  );
}

class _AuthForm extends StatefulWidget {
  const _AuthForm();

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final SessionController _session = Get.find<SessionController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _email = TextEditingController();

  bool _isRegistering = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _username.dispose();
    _displayName.dispose();
    _email.dispose();
    super.dispose();
  }

  /// The demo has no accounts, so this screen is never on the way to anything.
  /// It stays reachable, and this is the way out of it.
  Future<void> _continueWithoutAnAccount() async {
    if (await _session.ensureReadyForLive()) {
      Get.offAllNamed<void>(AppRoutes.home);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final bool ok = _isRegistering
        ? await _session.register(
            username: _username.text.trim(),
            displayName: _displayName.text.trim().isEmpty
                ? _username.text.trim()
                : _displayName.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          )
        : await _session.login(
            identifier: _identifier.text.trim(),
            password: _password.text,
          );

    if (ok) {
      Get.offAllNamed<void>(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            const _Brand(),
            const SizedBox(height: 28),

            if (AppConfig.demoMode) ...<Widget>[
              _DemoNotice(onContinue: _continueWithoutAnAccount),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 8),

            if (_isRegistering) ...<Widget>[
              _Field(
                controller: _username,
                label: 'Username',
                hint: 'lowercase, numbers, dot or underscore',
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  final String input = (value ?? '').trim();
                  if (!RegExp(r'^[a-z0-9_.]{3,24}$').hasMatch(input)) {
                    return '3-24 characters: a-z, 0-9, dot or underscore';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _displayName,
                label: 'Display name',
                hint: 'shown to viewers',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  final String input = (value ?? '').trim();
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
            ] else
              _Field(
                controller: _identifier,
                label: 'Username or email',
                textInputAction: TextInputAction.next,
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? 'Required' : null,
              ),

            const SizedBox(height: 12),
            _Field(
              controller: _password,
              label: 'Password',
              obscure: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 19,
                  color: LiveColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (String? value) {
                if ((value ?? '').length < 8) {
                  return 'At least 8 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 10),
            Obx(() {
              final String? error = _session.errorMessage.value;
              if (error == null) {
                return const SizedBox(height: 10);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: LiveColors.live,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: LiveTextStyles.caption.copyWith(
                          color: LiveColors.live,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),
            Obx(
              () => SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: LiveColors.accent,
                    foregroundColor: LiveColors.accentInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        LiveMetrics.pillRadius,
                      ),
                    ),
                  ),
                  onPressed: _session.isBusy.value ? null : _submit,
                  child: _session.isBusy.value
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: LiveColors.accentInk,
                          ),
                        )
                      : Text(
                          _isRegistering ? 'Create account' : 'Sign in',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            TextButton(
              onPressed: () => setState(() {
                _isRegistering = !_isRegistering;
                _session.errorMessage.value = null;
                _formKey.currentState?.reset();
              }),
              style: TextButton.styleFrom(
                foregroundColor: LiveColors.textSecondary,
              ),
              child: Text(
                _isRegistering
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account',
                style: LiveTextStyles.caption,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: LiveColors.live,
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: LiveColors.live.withValues(alpha: 0.4),
              blurRadius: 26,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.videocam_rounded,
          size: 36,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 18),
      Text('Elite Live', style: LiveTextStyles.displayLarge),
      const SizedBox(height: 6),
      Text(
        'Go live, send gifts, climb the leaderboard',
        style: LiveTextStyles.caption,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    validator: validator,
    onFieldSubmitted: onSubmitted,
    style: LiveTextStyles.body,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: LiveTextStyles.caption,
      hintStyle: LiveTextStyles.caption.copyWith(
        color: LiveColors.textMuted,
        fontSize: 11.5,
      ),
      filled: true,
      fillColor: LiveColors.surface,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LiveColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LiveColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: LiveColors.live),
      ),
    ),
  );
}

/// Shown only in the local build. There is no server to reach and no account
/// to create, so the form below is a demonstration and this is the way past
/// it.
class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    decoration: BoxDecoration(
      color: LiveColors.surface,
      borderRadius: BorderRadius.circular(LiveMetrics.cardRadius),
      border: Border.all(color: LiveColors.accent.withValues(alpha: 0.45)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.offline_bolt_rounded,
              size: 17,
              color: LiveColors.accent,
            ),
            const SizedBox(width: 9),
            Text(
              'Demo mode',
              style: LiveTextStyles.title.copyWith(fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'This build runs entirely on your device. No server, no sign-in: '
          'any credentials work, or skip the form completely.',
          style: LiveTextStyles.caption.copyWith(height: 1.45),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: const Text('Continue without an account'),
            style: TextButton.styleFrom(foregroundColor: LiveColors.accent),
          ),
        ),
      ],
    ),
  );
}
