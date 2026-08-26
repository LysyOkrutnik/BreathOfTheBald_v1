import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:okrutnik_breath/logic/notifiers/session_notifier.dart';
import 'package:okrutnik_breath/logic/path/cold_shower.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/locale_provider.dart';
import 'package:okrutnik_breath/ui/screens/splash_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Required top-level entry point for background/terminated FCM messages —
/// Android already auto-displays a "notification"-payload push on its own
/// while the app isn't in the foreground, so this only needs to exist (the
/// plugin requires *a* handler to be registered at all); there's nothing
/// extra to do here for a plain title/body announcement.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load locale data so DateFormat can render localized month/weekday names
  // (used by the planner calendar).
  await initializeDateFormatting();

  // Android-only app — no firebase_options.dart needed; the google-services
  // Gradle plugin already injects the config from google-services.json at
  // build time, which Firebase.initializeApp() picks up natively.
  await Firebase.initializeApp();

  // Initialize notifications once; the same instance is shared app-wide via the
  // provider override below.
  final notificationService = NotificationService();
  await notificationService.init();

  // Without this, an FCM push (e.g. an admin announcement) arriving while
  // the app is open in the foreground was silently dropped — Android only
  // auto-displays a "notification"-payload push on its own while the app is
  // backgrounded/killed; in the foreground it's delivered here instead, for
  // the app to show manually.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    if (notification == null) return;
    notificationService.showNow(
      title: notification.title ?? '',
      body: notification.body ?? '',
    );
  });

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

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  static const _widget = HomeWidgetService();
  StreamSubscription<Uri?>? _widgetClickSub;

  /// Guards against the same widget launch being delivered twice (cold start
  /// fires both `initiallyLaunchedFromHomeWidget` and the `widgetClicked`
  /// stream), which would otherwise be handled twice.
  bool _handlingQuickstart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Handle the home-screen widget launching the app.
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then((uri) => _handleWidgetUri(uri, coldStart: true));
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    // Cold start: the daily reminder's body may be several days stale if the
    // user hasn't finished a session since (that's otherwise the only thing
    // that refreshes it).
    ref.read(sessionProvider.notifier).refreshDailyReminderContent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionProvider.notifier).refreshDailyReminderContent();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    super.dispose();
  }

  void _handleWidgetUri(Uri? uri, {bool coldStart = false}) {
    if (uri == null) return;

    if (uri.host == 'coldshower') {
      _handleColdShowerFromWidget();
      return;
    }

    if (uri.host != 'quickstart') return;
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

  /// A no-op if already logged today — the widget button stays tappable
  /// (just shown dimmed) rather than needing a disabled-click affordance.
  /// Waits for the real session-history state rather than trusting whatever
  /// `coldShowerDoneTodayProvider` happens to read synchronously: on a cold
  /// start triggered by the widget tap itself, the underlying DB stream may
  /// not have emitted yet, which would otherwise read "not done" even when
  /// it was already logged earlier that day — double-logging XP and a
  /// duplicate history row.
  Future<void> _handleColdShowerFromWidget() async {
    await ref.read(sessionHistoryProvider.future);
    if (!ref.read(coldShowerDoneTodayProvider)) {
      await logColdShowerSession(ref);
    }
    _pushWidgetState();
  }

  void _pushWidgetState() {
    final isPl = ref.read(localeProvider).languageCode == 'pl';
    final streak = ref.read(userProfileProvider).value?.dailyStreak ?? 0;
    _widget.update(
      streak: streak,
      streakLabel: isPl ? 'dni serii' : 'day streak',
      startLabel: isPl ? 'ODDYCHAJ' : 'BREATHE',
      coldShowerDone: ref.read(coldShowerDoneTodayProvider),
      coldShowerLabel: isPl ? 'ZIMNY PRYSZNIC' : 'COLD SHOWER',
      coldShowerDoneLabel: isPl ? 'PRYSZNIC ZALICZONY' : 'SHOWER DONE',
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    // Keep the home-screen widget's streak and cold-shower checkbox in sync.
    ref.listen(userProfileProvider, (prev, next) {
      if (next.value != null) _pushWidgetState();
    });
    ref.listen(coldShowerDoneTodayProvider, (prev, next) => _pushWidgetState());

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
