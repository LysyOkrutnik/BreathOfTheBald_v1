import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/core/notifications/notification_service.dart';
import 'package:okrutnik_breath/core/widget/home_widget_service.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/locale_provider.dart';
import 'package:okrutnik_breath/ui/screens/splash_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load locale data so DateFormat can render localized month/weekday names
  // (used by the planner calendar).
  await initializeDateFormatting();

  // Initialize notifications once; the same instance is shared app-wide via the
  // provider override below.
  final notificationService = NotificationService();
  await notificationService.init();

  // Enforce immersive fullscreen to hide system UI and minimize distractions during sessions.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  static const _widget = HomeWidgetService();
  StreamSubscription<Uri?>? _widgetClickSub;

  /// Guards against the same widget launch being delivered twice (cold start
  /// fires both `initiallyLaunchedFromHomeWidget` and the `widgetClicked`
  /// stream), which would otherwise be handled twice.
  bool _handlingQuickstart = false;

  @override
  void initState() {
    super.initState();
    // Handle the home-screen widget launching the app.
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then((uri) => _handleWidgetUri(uri, coldStart: true));
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  void _handleWidgetUri(Uri? uri, {bool coldStart = false}) {
    if (uri == null || uri.host != 'quickstart') return;
    if (_handlingQuickstart) return; // ignore the duplicate delivery
    _handlingQuickstart = true;

    // The widget should let the user pick a method, so just bring the app to
    // the menu. Cold start already lands on the menu via the splash; for a
    // backgrounded app, pop back to the menu (the first route).
    if (!coldStart) {
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
    }
    // Re-arm after a short window so future taps work.
    Future.delayed(const Duration(seconds: 2), () => _handlingQuickstart = false);
  }

  void _pushStreakToWidget(int streak) {
    final isPl = ref.read(localeProvider).languageCode == 'pl';
    _widget.update(
      streak: streak,
      streakLabel: isPl ? 'dni serii' : 'day streak',
      startLabel: isPl ? 'ODDYCHAJ' : 'BREATHE',
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    // Keep the home-screen widget's streak in sync with the profile.
    ref.listen(userProfileProvider, (prev, next) {
      final profile = next.value;
      if (profile != null) _pushStreakToWidget(profile.dailyStreak);
    });

    return MaterialApp(
      title: 'Breath of the Bald',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: L10n.all,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
