import 'package:flutter/material.dart';

import '../../../../domain/entities/user_profile.dart';
import '../../../session/presentation/providers/session_provider.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._session);

  final SessionProvider _session;

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final resetEmailController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool agreedToTerms = false;
  bool resetLinkSent = false;

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
  }

  void clearLoginErrors() {
    emailError = null;
    passwordError = null;
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
        fullName: existingName.isEmpty ? 'Abdullah' : existingName,
        email: emailController.text.trim(),
        streakDays: existingName.isEmpty ? 12 : _session.profile.streakDays,
      ),
    );
  }

  void completeGoogleAuth({required bool isSignup}) {
    _session.updateProfile(
      UserProfile(
        fullName: isSignup ? 'Abdullah Khan' : (_session.profile.fullName.isEmpty ? 'Abdullah' : _session.profile.fullName),
        email: 'abdullah@gmail.com',
        streakDays: isSignup ? 1 : 12,
      ),
    );
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
