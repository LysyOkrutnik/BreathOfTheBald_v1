import 'dart:developer' as developer;

import 'package:home_widget/home_widget.dart';

/// Pushes data to the Android home-screen widget (streak + quick-start label).
class HomeWidgetService {
  const HomeWidgetService();

  static const _qualifiedAndroidName =
      'com.okrutnik.okrutnik_breath.BreathWidgetProvider';

  Future<void> update({
    required int streak,
    required String streakLabel,
    required String startLabel,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await HomeWidget.saveWidgetData<String>('streak_label', streakLabel);
      await HomeWidget.saveWidgetData<String>('start_label', startLabel);
      await HomeWidget.updateWidget(qualifiedAndroidName: _qualifiedAndroidName);
    } catch (e, st) {
      developer.log('Home widget update failed',
          name: 'HomeWidgetService', error: e, stackTrace: st);
    }
  }
}
