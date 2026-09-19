import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final auth = context.read<AuthService>();
    if (!_agreed) {
      _toast('Please accept the Terms & Privacy to continue.');
      return;
    }
    if (auth.isConfigured &&
        (_email.text.trim().isEmpty || _password.text.length < 6)) {
      _toast('Enter an email and a password of at least 6 characters.');
      return;
    }
    setState(() => _loading = true);
    try {
      await auth.signUp(_email.text, _password.text, name: _name.text.trim());
      if (!mounted) return;
      // If the project requires email confirmation, there's no session yet.
      if (auth.isConfigured && !auth.isSignedIn) {
        _toast('Check your email to confirm your account, then sign in.');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        );
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const Shell()),
        (_) => false,
      );
    } catch (e) {
      // Surface the real reason — most often "Signups not allowed for this
      // instance" (enable it in Auth settings) or "User already registered".
      if (mounted) {
        _toast(e is AuthException ? e.message : 'Could not create account: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
              Text('Create your\nwardrobe', style: serif(context, 40)),
              const SizedBox(height: 8),
              Text(
                'Two minutes to a closet that thinks with you.',
                style: TextStyle(fontFamily: kSans, fontSize: 15, color: t.ink2),
              ),
              const SizedBox(height: 32),
              VessField(hint: 'Full name', controller: _name),
              const SizedBox(height: 14),
              VessField(
                hint: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              VessField(
                hint: 'Create password',
                obscure: true,
                controller: _password,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => setState(() => _agreed = !_agreed),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _agreed ? t.accentSoft : Colors.transparent,
                        border: Border.all(color: _agreed ? t.accent : t.line),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: _agreed
                          ? Icon(Icons.check, size: 14, color: t.accent)
                          : null,
                    ),
                    const SizedBox(width: 11),
                    Text(
                      'I agree to the Terms & Privacy',
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 13, color: t.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              VessPrimaryButton(
                label: 'Continue',
                loading: _loading,
                onTap: _continue,
              ),
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Have an account? ',
                        style: TextStyle(
                            fontFamily: kSans, fontSize: 14, color: t.ink2)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                      ),
                      child: Text(
                        'Sign in',
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
