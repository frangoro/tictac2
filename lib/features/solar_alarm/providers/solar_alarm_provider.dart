import 'package:flutter/material.dart';

class SolarAlarmProvider extends ChangeNotifier {
  bool enabled = false;

  void toggleEnabled() {
    enabled = !enabled;
    notifyListeners();
  }
}
