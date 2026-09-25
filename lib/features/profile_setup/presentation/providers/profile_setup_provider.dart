import 'package:flutter/material.dart';

import '../../../../domain/entities/college.dart';
import '../../../../domain/entities/mbbs_year.dart';
import '../../../../domain/entities/user_profile.dart';
import '../../../../domain/repositories/college_repository.dart';
import '../../../session/presentation/providers/session_provider.dart';

class ProfileSetupProvider extends ChangeNotifier {
  ProfileSetupProvider(this._collegeRepository, this._session) {
    nameController.text = _session.profile.fullName;
    _loadColleges();
  }

  final CollegeRepository _collegeRepository;
  final SessionProvider _session;

  final nameController = TextEditingController();
  final searchController = TextEditingController();

  int step = 1;
  bool hasAvatar = false;
  MbbsYear? selectedYear;
  College? selectedCollege;
  List<College> colleges = const [];
  bool showCollegeResults = false;
  String? nameError;
  String? yearError;
  String? collegeError;

  void prepareFromSession() {
    step = 1;
    hasAvatar = false;
    selectedYear = null;
    selectedCollege = null;
    showCollegeResults = false;
    nameError = null;
    yearError = null;
    collegeError = null;
    searchController.clear();
    nameController.text = _session.profile.fullName;
    notifyListeners();
  }

  Future<void> _loadColleges([String query = '']) async {
    colleges = await _collegeRepository.search(query);
    notifyListeners();
  }

  void onNameChanged(String value) {
    nameError = null;
    notifyListeners();
  }

  void toggleAvatar() {
    hasAvatar = !hasAvatar;
    notifyListeners();
  }

  void selectYear(MbbsYear year) {
    selectedYear = year;
    yearError = null;
    notifyListeners();
  }

  Future<void> onCollegeQueryChanged(String query) async {
    showCollegeResults = true;
    await _loadColleges(query);
  }

  void selectCollege(College college) {
    selectedCollege = college;
    searchController.text = college.name;
    showCollegeResults = false;
    collegeError = null;
    notifyListeners();
  }

  bool validateCurrentStep() {
    nameError = null;
    yearError = null;
    collegeError = null;

    if (step == 1 && nameController.text.trim().isEmpty) {
      nameError = 'Please enter your name';
      notifyListeners();
      return false;
    }
    if (step == 2 && selectedYear == null) {
      yearError = 'Please select your MBBS year';
      notifyListeners();
      return false;
    }
    if (step == 3 && selectedCollege == null) {
      collegeError = 'Please select your medical college';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  bool continueStep() {
    if (!validateCurrentStep()) return false;
    if (step < 3) {
      step += 1;
      notifyListeners();
      return false;
    }
    _persist();
    return true;
  }

  void goBack() {
    if (step > 1) {
      step -= 1;
      notifyListeners();
    }
  }

  void _persist() {
    _session.updateProfile(
      UserProfile(
        fullName: nameController.text.trim(),
        email: _session.profile.email,
        year: selectedYear,
        college: selectedCollege,
        hasAvatar: hasAvatar,
        streakDays: _session.profile.streakDays == 0 ? 1 : _session.profile.streakDays,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    searchController.dispose();
    super.dispose();
  }
}
