import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  LevelData? _selectedLevel;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isScheduleActive = false;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final levelKey = prefs.getString('scheduled_level_key');
      final hour = prefs.getInt('scheduled_hour') ?? 10;
      final minute = prefs.getInt('scheduled_minute') ?? 0;
      final isActive = prefs.getBool('schedule_active') ?? false;

      if (levelKey != null) {
        _selectedLevel = LevelData.levels[levelKey];
      }
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
      _isScheduleActive = isActive;

      setState(() {});
    } catch (e) {
      debugPrint('Error loading schedule: $e');
    }
  }

  Future<void> _saveSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedLevel != null) {
        await prefs.setString('scheduled_level_key', _selectedLevel!.key);
        await prefs.setInt('scheduled_hour', _selectedTime.hour);
        await prefs.setInt('scheduled_minute', _selectedTime.minute);
        await prefs.setBool('schedule_active', _isScheduleActive);

        // Schedule notification if active - at selected time
        if (_isScheduleActive) {
          await _notificationService.scheduleReminderAtTime(
            _selectedTime.hour,
            _selectedTime.minute,
          );
          debugPrint('Notification scheduled for ${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L10n.get(context, 'scheduler_saved')),
              backgroundColor: AppTheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving schedule: $e');
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            primaryColor: AppTheme.primary,
            dialogBackgroundColor: AppTheme.background,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            L10n.get(context, 'scheduler_title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textLight,
                              fontWeight: FontWeight.w300,
                              fontSize: 20,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          L10n.get(context, 'scheduler_select_exercise'),
                          style: const TextStyle(
                            color: AppTheme.textDim,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withAlpha(77)),
                          ),
                          child: DropdownButton<LevelData>(
                            value: _selectedLevel,
                            hint: Text(
                              L10n.get(context, 'scheduler_choose_level'),
                              style: const TextStyle(color: AppTheme.textDim),
                            ),
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: AppTheme.background,
                            items: LevelData.levels.values.map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Text(
                                  L10n.get(context, level.title),
                                  style: const TextStyle(color: AppTheme.textLight),
                                ),
                              );
                            }).toList(),
                            onChanged: (LevelData? value) {
                              setState(() {
                                _selectedLevel = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          L10n.get(context, 'scheduler_select_time'),
                          style: const TextStyle(
                            color: AppTheme.textDim,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _selectTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withAlpha(77)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedTime.format(context),
                                  style: const TextStyle(
                                    color: AppTheme.textLight,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Icon(Icons.access_time, color: AppTheme.primary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              L10n.get(context, 'scheduler_enable_notifications'),
                              style: const TextStyle(
                                color: AppTheme.textLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Switch(
                              value: _isScheduleActive,
                              onChanged: (value) {
                                setState(() {
                                  _isScheduleActive = value;
                                });
                              },
                              activeColor: AppTheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: _saveSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            L10n.get(context, 'scheduler_save'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

