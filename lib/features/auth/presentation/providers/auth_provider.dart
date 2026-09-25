import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../data/datasources/auth_remote.dart';
import '../../../../domain/entities/user_profile.dart';
import '../../../session/presentation/providers/session_provider.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._session, this._authRemote);

  final SessionProvider _session;
  final AuthRemote _authRemote;

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final resetEmailController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool agreedToTerms = false;
  bool resetLinkSent = false;
  bool isLoading = false;
  String? formError;

  String? fullNameError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  String? termsError;
  String? resetEmailError;

  void togglePassword() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  void toggleConfirmPassword() {
    obscureConfirmPassword = !obscureConfirmPassword;
    notifyListeners();
  }

  void setAgreedToTerms(bool? value) {
    agreedToTerms = value ?? false;
    termsError = null;
    notifyListeners();
  }

  void clearSignupErrors() {
    fullNameError = null;
    emailError = null;
    passwordError = null;
    confirmPasswordError = null;
    termsError = null;
    formError = null;
  }

  void clearLoginErrors() {
    emailError = null;
    passwordError = null;
    formError = null;
  }

  bool validateSignup() {
    clearSignupErrors();
    final name = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;

    if (name.isEmpty) fullNameError = 'Please enter your full name';
    if (!_isValidEmail(email)) emailError = 'Enter a valid email address';
    if (password.length < 6) passwordError = 'Password must be at least 6 characters';
    if (confirm != password) confirmPasswordError = 'Passwords do not match';
    if (!agreedToTerms) termsError = 'Please accept the terms to continue';

    notifyListeners();
    return fullNameError == null &&
        emailError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        termsError == null;
  }

  bool validateLogin() {
    clearLoginErrors();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (!_isValidEmail(email)) emailError = 'Enter a valid email address';
    if (password.isEmpty) passwordError = 'Please enter your password';

    notifyListeners();
    return emailError == null && passwordError == null;
  }

  bool validateResetEmail() {
    resetEmailError = null;
    if (!_isValidEmail(resetEmailController.text.trim())) {
      resetEmailError = 'Enter a valid email address';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<bool> loginWithApi() async {
    if (!validateLogin()) return false;
    isLoading = true;
    formError = null;
    notifyListeners();
    try {
      final data = await _authRemote.login(
        emailController.text.trim(),
        passwordController.text,
      );
      await _session.applyAuthSuccess(
        token: data['access_token'] as String,
        id: data['user_id'].toString(),
        fullName: data['full_name'] as String? ?? '',
        email: data['email'] as String? ?? emailController.text.trim(),
      );
      try {
        final me = await _authRemote.me();
        await _session.applyAuthSuccess(
          token: data['access_token'] as String,
          id: data['user_id'].toString(),
          fullName: me['full_name'] as String? ?? data['full_name'] as String? ?? '',
          email: me['email'] as String? ?? data['email'] as String? ?? '',
          subscriptionExpires: me['subscription_expires_at']?.toString(),
        );
        final streak = me['streak_days'] as int?;
        if (streak != null) {
          _session.updateProfile(_session.profile.copyWith(streakDays: streak));
        }
      } catch (_) {
        // token already applied
      }
      return true;
    } catch (e) {
      formError = apiErrorMessage(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerWithApi() async {
    if (!validateSignup()) return false;
    isLoading = true;
    formError = null;
    notifyListeners();
    try {
      final data = await _authRemote.register(
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      await _session.applyAuthSuccess(
        token: data['access_token'] as String,
        id: data['user_id'].toString(),
        fullName: data['full_name'] as String? ?? fullNameController.text.trim(),
        email: data['email'] as String? ?? emailController.text.trim(),
      );
      return true;
    } catch (e) {
      formError = apiErrorMessage(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void completeSignup() {
    _session.updateProfile(
      UserProfile(
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        streakDays: 1,
      ),
    );
  }

  void completeLogin() {
    final existingName = _session.profile.fullName;
    _session.updateProfile(
      _session.profile.copyWith(
        fullName: existingName.isEmpty ? 'Student' : existingName,
        email: emailController.text.trim(),
      ),
    );
  }

  void completeGoogleAuth({required bool isSignup}) {
    formError = 'Google sign-in is not connected yet. Use email login.';
    notifyListeners();
  }

  void sendResetLink() {
    resetLinkSent = true;
    notifyListeners();
  }

  void resetForgotPassword() {
    resetLinkSent = false;
    resetEmailController.clear();
    resetEmailError = null;
    notifyListeners();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    resetEmailController.dispose();
    super.dispose();
  }
}
