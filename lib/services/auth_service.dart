import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';

/// Authentication, with a demo fallback.
///
/// When Supabase is configured this wraps real email/password auth and reflects
/// Supabase's auth state. When it isn't (demo mode), sign-in is a local no-op so
/// the prototype still runs end-to-end.
class AuthService extends ChangeNotifier {
  AuthService() {
    if (SupabaseService.isReady) {
      _sub = SupabaseService.client.auth.onAuthStateChange.listen((_) {
        notifyListeners();
      });
    }
  }

  StreamSubscription<AuthState>? _sub;
  bool _demoSignedIn = false;

  bool get isConfigured => SupabaseService.isReady;

  bool get isSignedIn => isConfigured
      ? SupabaseService.client.auth.currentUser != null
      : _demoSignedIn;

  User? get user =>
      isConfigured ? SupabaseService.client.auth.currentUser : null;

  Future<void> signIn(String email, String password) async {
    if (!isConfigured) {
      _demoSignedIn = true;
      notifyListeners();
      return;
    }
    await SupabaseService.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp(String email, String password, {String? name}) async {
    if (!isConfigured) {
      _demoSignedIn = true;
      notifyListeners();
      return;
    }
    await SupabaseService.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: name == null ? null : {'display_name': name},
    );
  }

  Future<void> signOut() async {
    if (!isConfigured) {
      _demoSignedIn = false;
      notifyListeners();
      return;
    }
    await SupabaseService.client.auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
