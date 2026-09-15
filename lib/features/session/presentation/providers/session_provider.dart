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

  UserProfile get profile => _profile;

  Future<void> hydrate() async {
    final snapshot = await _prefs.load();
    onboardingDone = snapshot.onboardingDone;
    isLoggedIn = snapshot.isLoggedIn;
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

  Future<void> signIn() async {
    isLoggedIn = true;
    onboardingDone = true;
    notifyListeners();
    await _persist();
  }

  Future<void> signOut() async {
    isLoggedIn = false;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    return _prefs.save(
      SessionSnapshot(
        onboardingDone: onboardingDone,
        isLoggedIn: isLoggedIn,
        profile: _profile,
      ),
    );
  }
}
