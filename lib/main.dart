import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// Identificador único para la alarma en Android
const int kSolarAlarmId = 101;

@pragma('vm:entry-point')
void alarmCallback() {
  // Función ejecutada en segundo plano por el AlarmManager de Android
  debugPrint("¡Ejecutando activación del despertador solar!");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(const SolarAlarmApp());
}

class SolarAlarmApp extends StatelessWidget {
  const SolarAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Despertador Solar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SolarAlarmScreen(),
    );
  }
}

class SolarAlarmScreen extends StatefulWidget {
  const SolarAlarmScreen({super.key});

  @override
  State<SolarAlarmScreen> createState() => _SolarAlarmScreenState();
}

class _SolarAlarmScreenState extends State<SolarAlarmScreen> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  bool _isAlarmEnabled = false;

  // Lógica de simulación del sol
  final int _durationInSeconds = 30; // Para la demostración
  int _elapsedSeconds = 0;
  bool _isSimulating = false;
  Timer? _timer;

  // Gradientes
  final Color _nightColor = const Color(0xFF050510);
  final Color _dawnColor = const Color(0xFF8B263E);
  final Color _sunriseColor = const Color(0xFFFF7E5F);
  final Color _fullSunColor = const Color(0xFFFEB47B);

  @override
  void dispose() {
    _timer?.cancel();
    _resetBrightness();
    super.dispose();
  }

  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
  }

  Future<void> _updateBrightness(double progress) async {
    try {
      double targetBrightness = 0.01 + (progress * 0.99);
      await ScreenBrightness().setScreenBrightness(targetBrightness);
    } catch (_) {}
  }

  // Seleccionar la hora de la alarma
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      if (_isAlarmEnabled) {
        _scheduleDailyAlarm();
      }
    }
  }

  // Programar la alarma diaria con AndroidAlarmManager
  Future<void> _scheduleDailyAlarm() async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Si la hora elegida ya pasó hoy, programarla para mañana
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.periodic(
      const Duration(hours: 24),
      kSolarAlarmId,
      alarmCallback,
      startAt: scheduledDate,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alarma programada para las ${_selectedTime.format(context)} (diaria)',
          ),
        ),
      );
    }
  }

  Future<void> _cancelAlarm() async {
    await AndroidAlarmManager.cancel(kSolarAlarmId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarma desactivada')),
      );
    }
  }

  void _toggleAlarm(bool value) {
    setState(() {
      _isAlarmEnabled = value;
    });
    if (_isAlarmEnabled) {
      _scheduleDailyAlarm();
    } else {
      _cancelAlarm();
    }
  }

  void _startSunriseSimulation() {
    setState(() {
      _isSimulating = true;
      _elapsedSeconds = 0;
    });

    _updateBrightness(0.0);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_elapsedSeconds < _durationInSeconds) {
        setState(() {
          _elapsedSeconds++;
        });
        double progress = _elapsedSeconds / _durationInSeconds;
        _updateBrightness(progress);
      } else {
        _timer?.cancel();
      }
    });
  }

  void _stopSimulation() {
    _timer?.cancel();
    _resetBrightness();
    setState(() {
      _isSimulating = false;
      _elapsedSeconds = 0;
    });
  }

  Color _getCurrentBackgroundColor(double progress) {
    if (progress < 0.33) {
      return Color.lerp(_nightColor, _dawnColor, progress / 0.33)!;
    } else if (progress < 0.66) {
      return Color.lerp(_dawnColor, _sunriseColor, (progress - 0.33) / 0.33)!;
    } else {
      return Color.lerp(_sunriseColor, _fullSunColor, (progress - 0.66) / 0.34)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = _isSimulating ? (_elapsedSeconds / _durationInSeconds) : 0.0;
    Color backgroundColor = _getCurrentBackgroundColor(progress);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        color: backgroundColor,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wb_sunny_rounded,
                size: 80 + (progress * 40),
                color: Color.lerp(Colors.orange.shade900, Colors.yellow.shade200, progress),
              ),
              const SizedBox(height: 20),
              
              // Selector visual de Hora
              InkWell(
                onTap: () => _selectTime(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _selectedTime.format(context),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Toca para cambiar la hora de amanecer', style: TextStyle(color: Colors.white60)),
              
              const SizedBox(height: 30),
              
              // Switch de activación diaria
              SwitchListTile(
                title: const Text('Repetir todos los días', style: TextStyle(fontSize: 18)),
                subtitle: Text(_isAlarmEnabled ? 'Alarma diaria activa' : 'Desactivada'),
                value: _isAlarmEnabled,
                onChanged: _toggleAlarm,
                secondary: const Icon(Icons.alarm),
                contentPadding: const EdgeInsets.symmetric(horizontal: 40),
              ),

              const SizedBox(height: 40),

              // Botón de prueba rápida
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: _isSimulating ? Colors.redAccent : Colors.amber.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSimulating ? _stopSimulation : _startSunriseSimulation,
                icon: Icon(_isSimulating ? Icons.stop : Icons.play_arrow),
                label: Text(_isSimulating ? 'Detener Proyección' : 'Probar Amanecer (30s)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}