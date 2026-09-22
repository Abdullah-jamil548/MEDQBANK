import 'package:flutter/foundation.dart';

import '../../../../core/storage/app_prefs.dart';
import '../../../../domain/entities/user_profile.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider({AppPrefs? prefs}) : _prefs = prefs ?? AppPrefs();

  final AppPrefs _prefs;

  UserProfile _profile = const UserProfile();
  bool onboardingDone = false;
  bool isLoggedIn = false;
  bool isReady = false;
  String? accessToken;
  String? userId;
  String? subscriptionExpiresAt;

  UserProfile get profile => _profile;

  Future<void> hydrate() async {
    final snapshot = await _prefs.load();
    onboardingDone = snapshot.onboardingDone;
    isLoggedIn = snapshot.isLoggedIn && (snapshot.accessToken?.isNotEmpty ?? false);
    accessToken = snapshot.accessToken;
    userId = snapshot.userId;
    subscriptionExpiresAt = snapshot.subscriptionExpiresAt;
    _profile = snapshot.profile;
    isReady = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboardingDone = true;
    notifyListeners();
    await _persist();
  }

  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
    _persist();
  }

  Future<void> applyAuthSuccess({
    required String token,
    required String id,
    required String fullName,
    required String email,
    String? subscriptionExpires,
  }) async {
    accessToken = token;
    userId = id;
    subscriptionExpiresAt = subscriptionExpires;
    _profile = _profile.copyWith(fullName: fullName, email: email);
    isLoggedIn = true;
    onboardingDone = true;
    notifyListeners();
    await _persist();
  }

  Future<void> signIn() async {
    isLoggedIn = true;
    onboardingDone = true;
    notifyListeners();
    await _persist();
  }

  Future<void> signOut() async {
    isLoggedIn = false;
    accessToken = null;
    userId = null;
    subscriptionExpiresAt = null;
    notifyListeners();
    await _prefs.clear();
    // Keep onboardingDone true so returning users land on login
    onboardingDone = true;
    await _persist();
  }

  Future<void> _persist() {
    return _prefs.save(
      SessionSnapshot(
        onboardingDone: onboardingDone,
        isLoggedIn: isLoggedIn,
        accessToken: accessToken,
        userId: userId,
        subscriptionExpiresAt: subscriptionExpiresAt,
        profile: _profile,
      ),
    );
  }
}
