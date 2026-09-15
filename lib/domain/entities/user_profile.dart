import 'college.dart';
import 'mbbs_year.dart';

class UserProfile {
  const UserProfile({
    this.fullName = '',
    this.email = '',
    this.year,
    this.college,
    this.hasAvatar = false,
    this.streakDays = 0,
    this.notificationsEnabled = false,
  });

  final String fullName;
  final String email;
  final MbbsYear? year;
  final College? college;
  final bool hasAvatar;
  final int streakDays;
  final bool notificationsEnabled;

  String get firstName {
    if (fullName.trim().isEmpty) return 'Student';
    return fullName.trim().split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    MbbsYear? year,
    College? college,
    bool? hasAvatar,
    int? streakDays,
    bool? notificationsEnabled,
    bool clearYear = false,
    bool clearCollege = false,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      year: clearYear ? null : (year ?? this.year),
      college: clearCollege ? null : (college ?? this.college),
      hasAvatar: hasAvatar ?? this.hasAvatar,
      streakDays: streakDays ?? this.streakDays,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
