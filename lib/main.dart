import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const int kSolarAlarmId = 101;

const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
  'canal_alarma_id',
  'Alarmas',
  channelDescription: 'Canal para alertas de alarma',
  importance: Importance.max,
  priority: Priority.max,
  fullScreenIntent: true, // <-- ESENCIAL: Abre la app o notificación a pantalla completa sobre el bloqueo
  category: AndroidNotificationCategory.alarm, // Indica al SO que es una alarma real
  visibility: NotificationVisibility.public,
);

@pragma('vm:entry-point')
void alarmCallback() {
  debugPrint("⚡ [ALARM TRIGGERED] ¡Ejecutando servicio de alarma!");
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
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isAlarmEnabled = false;
  int _sunriseDurationMinutes = 20; // Reincorporada la duración del amanecer

  int _elapsedSeconds = 0;
  bool _isSimulating = false;
  Timer? _simulationTimer;
  Timer? _checkerTimer;

  final Color _nightColor = const Color(0xFF050510);
  final Color _dawnColor = const Color(0xFF8B263E);
  final Color _sunriseColor = const Color(0xFFFF7E5F);
  final Color _fullSunColor = const Color(0xFFFEB47B);

  @override
  void initState() {
    super.initState();
    // Ejecutar cuando se active el temporizador/alarma:
    WakelockPlus.enable(); 
    // Revisa la hora cada 5 segundos si la app permanece abierta
    _checkerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isAlarmEnabled && !_isSimulating) {
        final now = TimeOfDay.now();
        if (now.hour == _selectedTime.hour && now.minute == _selectedTime.minute) {
          _startSunriseSimulation();
        }
      }
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _checkerTimer?.cancel();
    _resetBrightness();
    WakelockPlus.disable();
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

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
      if (_isAlarmEnabled) {
        _scheduleDailyAlarm();
      }
    }
  }

  Future<void> _scheduleDailyAlarm() async {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.oneShotAt(
      scheduledDate,
      kSolarAlarmId,
      alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    if (mounted) {
      final diff = scheduledDate.difference(now);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alarma en ${diff.inMinutes} min (${_selectedTime.format(context)})',
          ),
        ),
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
      AndroidAlarmManager.cancel(kSolarAlarmId);
    }
  }

  void _startSunriseSimulation({bool acceleratedTest = false}) {
    setState(() {
      _isSimulating = true;
      _elapsedSeconds = 0;
    });

    _updateBrightness(0.0);
    int totalSeconds = acceleratedTest ? 30 : (_sunriseDurationMinutes * 60);

    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_elapsedSeconds < totalSeconds) {
        setState(() {
          _elapsedSeconds++;
        });
        double progress = _elapsedSeconds / totalSeconds;
        _updateBrightness(progress);
      } else {
        _simulationTimer?.cancel();
      }
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
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
    int totalSec = _isSimulating ? 30 : (_sunriseDurationMinutes * 60);
    double progress = _isSimulating ? (_elapsedSeconds / totalSec) : 0.0;
    Color backgroundColor = _getCurrentBackgroundColor(progress);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        color: backgroundColor,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                Icon(
                  Icons.wb_sunny_rounded,
                  size: 80 + (progress * 40),
                  color: Color.lerp(Colors.orange.shade900, Colors.yellow.shade200, progress),
                ),
                const SizedBox(height: 20),

                // Hora
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
                const SizedBox(height: 5),
                const Text('Toca para cambiar la hora', style: TextStyle(color: Colors.white60)),

                const SizedBox(height: 25),

                // Ajuste de la Duración del Amanecer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Duración del amanecer:', style: TextStyle(fontSize: 16)),
                          Text('$_sunriseDurationMinutes min', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Slider(
                        value: _sunriseDurationMinutes.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '$_sunriseDurationMinutes min',
                        onChanged: (val) {
                          setState(() {
                            _sunriseDurationMinutes = val.toInt();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Interruptor de Activación
                SwitchListTile(
                  title: const Text('Activar Alarma', style: TextStyle(fontSize: 18)),
                  subtitle: Text(_isAlarmEnabled ? 'Alarma activa' : 'Desactivada'),
                  value: _isAlarmEnabled,
                  onChanged: _toggleAlarm,
                  secondary: const Icon(Icons.alarm),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 30),
                ),

                const SizedBox(height: 20),

                // Botón Probar Secuencia
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: _isSimulating ? Colors.redAccent : Colors.amber.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSimulating ? _stopSimulation : () => _startSunriseSimulation(acceleratedTest: true),
                  icon: Icon(_isSimulating ? Icons.stop : Icons.play_arrow),
                  label: Text(_isSimulating ? 'Detener Proyección' : 'Probar Amanecer (30s)'),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}