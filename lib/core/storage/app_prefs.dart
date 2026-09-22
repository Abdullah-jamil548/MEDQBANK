import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/college.dart';
import '../../domain/entities/mbbs_year.dart';
import '../../domain/entities/user_profile.dart';

class AppPrefs {
  static const sessionKey = 'medqbank.session.v2';

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<SessionSnapshot> load() async {
    final prefs = await _prefs();
    final raw = prefs?.getString(sessionKey);
    if (raw == null || raw.isEmpty) return const SessionSnapshot();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SessionSnapshot.fromJson(json);
    } catch (_) {
      return const SessionSnapshot();
    }
  }

  Future<void> save(SessionSnapshot snapshot) async {
    final prefs = await _prefs();
    await prefs?.setString(sessionKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs?.remove(sessionKey);
  }
}

class SessionSnapshot {
  const SessionSnapshot({
    this.onboardingDone = false,
    this.isLoggedIn = false,
    this.accessToken,
    this.userId,
    this.subscriptionExpiresAt,
    this.profile = const UserProfile(),
  });

  final bool onboardingDone;
  final bool isLoggedIn;
  final String? accessToken;
  final String? userId;
  final String? subscriptionExpiresAt;
  final UserProfile profile;

  Map<String, dynamic> toJson() {
    return {
      'onboardingDone': onboardingDone,
      'isLoggedIn': isLoggedIn,
      'accessToken': accessToken,
      'userId': userId,
      'subscriptionExpiresAt': subscriptionExpiresAt,
      'fullName': profile.fullName,
      'email': profile.email,
      'year': profile.year?.name,
      'collegeId': profile.college?.id,
      'collegeName': profile.college?.name,
      'collegeCity': profile.college?.city,
      'hasAvatar': profile.hasAvatar,
      'streakDays': profile.streakDays,
      'notificationsEnabled': profile.notificationsEnabled,
    };
  }

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    final yearName = json['year'] as String?;
    final collegeId = json['collegeId'] as String?;
    return SessionSnapshot(
      onboardingDone: json['onboardingDone'] as bool? ?? false,
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      accessToken: json['accessToken'] as String?,
      userId: json['userId'] as String?,
      subscriptionExpiresAt: json['subscriptionExpiresAt'] as String?,
      profile: UserProfile(
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        year: yearName == null
            ? null
            : MbbsYear.values.where((item) => item.name == yearName).firstOrNull,
        college: collegeId == null
            ? null
            : College(
                id: collegeId,
                name: json['collegeName'] as String? ?? '',
                city: json['collegeCity'] as String? ?? '',
              ),
        hasAvatar: json['hasAvatar'] as bool? ?? false,
        streakDays: json['streakDays'] as int? ?? 0,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      ),
    );
  }
}
