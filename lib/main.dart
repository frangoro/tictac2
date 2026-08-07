import 'package:flutter/material.dart';
import 'features/solar_alarm/screens/solar_alarm_screen.dart';
import 'features/workout_timer/screens/workout_timer_screen.dart';
import 'shared/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TicTac2',
      theme: appTheme(),
      home: const MyHomePage(title: 'TicTac2 Home'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Solar Alarm'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SolarAlarmScreen()),
            ),
          ),
          ListTile(
            title: const Text('Workout Timer'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkoutTimerScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
