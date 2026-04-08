import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/levels.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/ui/widgets/particle_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  LevelData? _selectedLevel;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _schedules = [];
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduleStrings = prefs.getStringList('workout_schedules') ?? [];
      
      setState(() {
        _schedules = scheduleStrings
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    }
  }

  Future<void> _addSchedule() async {
    if (_selectedLevel == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (scheduledDateTime.isBefore(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot schedule in the past!")),
          );
        }
        return;
      }

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final newSchedule = {
        'id': id,
        'levelKey': _selectedLevel!.key,
        'dateTime': scheduledDateTime.toIso8601String(),
      };

      _schedules.add(newSchedule);
      final strings = _schedules.map((s) => jsonEncode(s)).toList();
      await prefs.setStringList('workout_schedules', strings);

      
      await _addToSystemCalendar(newSchedule);

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.get(context, 'scheduler_saved')), backgroundColor: AppTheme.primary),
        );
      }
    } catch (e) {
      debugPrint('Error saving schedule: $e');
    }
  }

  Future<void> _addToSystemCalendar(Map<String, dynamic> schedule) async {
    final level = LevelData.levels[schedule['levelKey']];
    final dt = DateTime.parse(schedule['dateTime']);
    
    final Event event = Event(
      title: 'Breath of the Bald: ${L10n.get(context, level?.title ?? 'Session')}',
      description: 'Time for your breathing workout. Stay focused, stay bald.',
      location: 'Mindfulness Space',
      startDate: dt,
      endDate: dt.add(const Duration(minutes: 15)),
      iosParams: const IOSParams(reminder: Duration(minutes: 5)),
      androidParams: const AndroidParams(emailInvites: []),
    );

    
    await Add2Calendar.addEvent2Cal(event);
  }

  Future<void> _deleteSchedule(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _schedules.removeAt(index);
      final strings = _schedules.map((s) => jsonEncode(s)).toList();
      await prefs.setStringList('workout_schedules', strings);
      setState(() {});
    } catch (e) {
      debugPrint('Error deleting schedule: $e');
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isLandscape),
                Expanded(
                  child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: isLandscape ? 10 : 20),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.of(context).pop()),
          Expanded(
            child: Text(
              L10n.get(context, 'scheduler_title'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w300, fontSize: isLandscape ? 18 : 20, letterSpacing: 2.0),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildForm(),
          const SizedBox(height: 40),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          _buildScheduleList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildForm(),
          ),
        ),
        VerticalDivider(color: Colors.white.withAlpha(13), width: 1),
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildScheduleList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(L10n.get(context, 'scheduler_select_exercise'), style: const TextStyle(color: AppTheme.textDim, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        _buildDropdown(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildPickerTile(Icons.calendar_today, "${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}", _selectDate)),
            const SizedBox(width: 16),
            Expanded(child: _buildPickerTile(Icons.access_time, _selectedTime.format(context), _selectTime)),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _addSchedule,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(L10n.get(context, 'scheduler_save'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withAlpha(77))),
      child: DropdownButton<LevelData>(
        value: _selectedLevel,
        hint: Text(L10n.get(context, 'scheduler_choose_level'), style: const TextStyle(color: AppTheme.textDim)),
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: AppTheme.background,
        items: LevelData.levels.values.map((l) => DropdownMenuItem(value: l, child: Text(L10n.get(context, l.title), style: const TextStyle(color: AppTheme.textLight)))).toList(),
        onChanged: (v) => setState(() => _selectedLevel = v),
      ),
    );
  }

  Widget _buildPickerTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withAlpha(77))),
        child: Row(children: [Icon(icon, color: AppTheme.primary, size: 18), const SizedBox(width: 8), Text(label, style: const TextStyle(color: AppTheme.textLight, fontSize: 14))]),
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_schedules.isEmpty) return Center(child: Text(L10n.get(context, 'scheduler_no_schedules'), style: const TextStyle(color: Colors.white24)));

    return Column(
      children: _schedules.asMap().entries.map((entry) {
        final index = entry.key;
        final schedule = entry.value;
        final level = LevelData.levels[schedule['levelKey']];
        final dt = DateTime.parse(schedule['dateTime']);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withAlpha(13), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.get(context, level?.title ?? 'Unknown'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text("${dt.day}.${dt.month}.${dt.year} ${L10n.get(context, 'scheduler_at')} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18), onPressed: () => _deleteSchedule(index), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
        );
      }).toList(),
    );
  }
}
