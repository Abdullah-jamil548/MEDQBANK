import 'package:flutter/foundation.dart';

class OnboardingProvider extends ChangeNotifier {
  static const int totalPages = 3;

  int _pageIndex = 0;

  int get pageIndex => _pageIndex;
  bool get isLastPage => _pageIndex == totalPages - 1;

  void setPage(int index) {
    if (index == _pageIndex) return;
    _pageIndex = index;
    notifyListeners();
  }
}
