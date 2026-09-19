import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'register_screen.dart';
import 'shell.dart';

/// Shared field style for the auth screens.
class VessField extends StatelessWidget {
  const VessField({
    super.key,
    required this.hint,
    this.obscure = false,
    this.controller,
    this.keyboardType,
  });

  final String hint;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return SizedBox(
      height: 54,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(fontFamily: kSans, fontSize: 15, color: t.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontFamily: kSans, fontSize: 15, color: t.ink3),
          filled: true,
          fillColor: t.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: t.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: t.accent),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Text(
      text,
      style: TextStyle(
        fontFamily: kSans,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: t.ink2,
      ),
    );
  }
}

/// Full-width primary action (56px, 16px radius) used on the auth screens.
class VessPrimaryButton extends StatelessWidget {
  const VessPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: t.accent.withOpacity(0.26),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: kSans,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toShell() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const Shell()),
      (_) => false,
    );
  }

  Future<void> _signIn() async {
    final auth = context.read<AuthService>();
    if (auth.isConfigured &&
        (_email.text.trim().isEmpty || _password.text.isEmpty)) {
      _toast('Enter your email and password.');
      return;
    }
    setState(() => _loading = true);
    try {
      await auth.signIn(_email.text, _password.text);
      if (mounted) _toShell();
    } catch (e) {
      if (mounted) _toast(_authError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _social(String provider) {
    final auth = context.read<AuthService>();
    if (auth.isConfigured) {
      _toast('$provider sign-in is coming soon.');
    } else {
      // Demo mode — just proceed.
      auth.signIn('demo@vess.app', 'demo');
      _toShell();
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _authError(Object e) {
    // Surface the real Supabase reason (e.g. "Invalid login credentials",
    // "Email not confirmed", "Signups not allowed for this instance") so
    // failures are diagnosable instead of a generic message.
    if (e is AuthException) {
      if (e.message.contains('Invalid login')) {
        return 'Email or password is incorrect — Register first if you have no account.';
      }
      return e.message;
    }
    return 'Could not sign in: $e';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.vess;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 34, 30, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VessBackButton(),
              const SizedBox(height: 34),
              Text('Welcome back', style: serif(context, 40)),
              const SizedBox(height: 8),
              Text(
                'Your wardrobe is exactly where you left it.',
                style: TextStyle(fontFamily: kSans, fontSize: 15, color: t.ink2),
              ),
              const SizedBox(height: 34),
              const _FieldLabel('Email'),
              const SizedBox(height: 14),
              VessField(
                hint: 'maya@studio.co',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Password'),
              const SizedBox(height: 14),
              VessField(
                hint: '••••••••••',
                obscure: true,
                controller: _password,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: t.accent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              VessPrimaryButton(
                label: 'Sign in',
                loading: _loading,
                onTap: _signIn,
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(child: Divider(color: t.line, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 12.5, color: t.ink3),
                    ),
                  ),
                  Expanded(child: Divider(color: t.line, height: 1)),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(child: _SocialButton('Apple', onTap: () => _social('Apple'))),
                  const SizedBox(width: 12),
                  Expanded(child: _SocialButton('Google', onTap: () => _social('Google'))),
                ],
              ),
              const SizedBox(height: 26),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('New here? ',
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 14, color: t.ink2)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: Text(
                        'Create account',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.vess;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: t.card,
          foregroundColor: t.ink,
          side: BorderSide(color: t.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: kSans,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
