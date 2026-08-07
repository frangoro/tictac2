import 'package:flutter/material.dart';

class WorkoutTimerProvider extends ChangeNotifier {
  int sets = 3;
  Duration workDuration = const Duration(seconds: 30);
  Duration restDuration = const Duration(seconds: 15);

  void updateSets(int value) {
    sets = value;
    notifyListeners();
  }
}
