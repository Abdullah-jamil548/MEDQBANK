import 'package:flutter/foundation.dart';

class MainNavProvider extends ChangeNotifier {
  int index = 0;

  void setIndex(int value) {
    if (index == value) return;
    index = value;
    notifyListeners();
  }
}
