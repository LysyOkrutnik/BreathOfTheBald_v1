import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// In-app privacy policy. An account is required to use the app, and
/// training history syncs to the backend — this used to be optional/fully
/// offline, so keep this in sync with reality rather than the old "nothing
/// leaves your phone" claim. Still no ads or third-party analytics/tracking.
/// Text is inlined per-locale rather than living in the l10n map because it
/// is long-form legal copy.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _contact = 'rafalcharciarek@gmail.com';

  @override
  Widget build(BuildContext context) {
    final isPl = Localizations.localeOf(context).languageCode == 'pl';
    final sections = isPl ? _pl : _en;
    final updated = isPl ? 'Ostatnia aktualizacja: sierpień 2026'
                         : 'Last updated: August 2026';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 720 : 560),
                child: Column(
                  children: [
                    ScreenHeader(title: L10n.get(context, 'settings_privacy')),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        children: [
                          Text(
                            updated,
                            style: TextStyle(
                                color: AppTheme.textDim.withAlpha(180),
                                fontSize: 12),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          for (final s in sections) ...[
                            _Section(heading: s.$1, body: s.$2),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          GlassCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                              children: [
                                const Icon(Icons.mail_outline_rounded,
                                    color: AppTheme.primary, size: 20),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: SelectableText(
                                    _contact,
                                    style: const TextStyle(
                                        color: AppTheme.textLight, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<(String, String)> _pl = [
    (
      'Konto i dane, które przechowujemy',
      'Aplikacja wymaga konta (e-mail i hasło) do korzystania z niej. Adres '
          'e-mail i zahaszowane hasło, a także historia sesji, dzienniki '
          'freedivingu, własne presety i ustawienia planu są przechowywane na '
          'naszym serwerze, żeby były dostępne po zalogowaniu się na innym '
          'urządzeniu. Nie sprzedajemy i nie udostępniamy tych danych stronom '
          'trzecim, i nie zawieramy żadnych reklam ani zewnętrznych narzędzi '
          'analitycznych czy śledzących.'
    ),
    (
      'Zgłoszenia w apce',
      'Treść zgłoszenia wysłanego przez "Zgłoś problem/opinię" jest '
          'przypisana do Twojego konta i przechowywana do czasu jego '
          'rozpatrzenia — nie jest anonimowa.'
    ),
    (
      'Twoja kontrola nad danymi',
      'W Ustawieniach możesz w każdej chwili wyeksportować swoją historię '
          'treningową (CSV) oraz trwale usunąć konto razem z wszystkimi '
          'powiązanymi danymi na serwerze.'
    ),
    (
      'Dane na urządzeniu',
      'Ta sama historia sesji, statystyki, zaplanowane sesje, własne presety '
          'oraz ustawienia (w tym nazwa profilu) są też zapisywane lokalnie na '
          'Twoim urządzeniu, dla szybkiego dostępu offline. Odinstalowanie '
          'aplikacji usuwa lokalną kopię — dane na serwerze pozostają, dopóki '
          'nie usuniesz konta.'
    ),
    (
      'Powiadomienia',
      'Przypomnienia lokalne są planowane na urządzeniu i nie wymagają '
          'internetu. Jeśli włączysz powiadomienia push, token urządzenia jest '
          'zarejestrowany na serwerze, żeby moglibyśmy wysłać Ci przypomnienie '
          'lub ogłoszenie.'
    ),
    (
      'Uprawnienia',
      'Używamy jedynie: powiadomień (przypomnienia), wibracji (haptyka podczas '
          'sesji) oraz dokładnego alarmu (przypomnienie o zaplanowanej sesji o '
          'właściwej godzinie). Nie korzystamy z lokalizacji, kontaktów, '
          'aparatu ani mikrofonu.'
    ),
    (
      'Brak reklam i śledzenia',
      'Aplikacja nie zawiera reklam ani zewnętrznych narzędzi analitycznych '
          'czy śledzących.'
    ),
    (
      'Dzieci',
      'Aplikacja nie jest kierowana do dzieci i nie gromadzi świadomie żadnych '
          'danych od osób poniżej 13 roku życia.'
    ),
    (
      'Zdrowie i bezpieczeństwo',
      'Techniki oddechowe (w tym hiperwentylacja i wstrzymywanie oddechu) mogą '
          'powodować zawroty głowy lub omdlenie. Ćwicz w bezpiecznej pozycji, '
          'nigdy w wodzie ani podczas prowadzenia pojazdu. Aplikacja ma charakter '
          'edukacyjny i nie zastępuje porady lekarskiej.'
    ),
    (
      'Zmiany',
      'Możemy aktualizować tę politykę. Nowa wersja będzie dostępna w '
          'aplikacji. Pytania kieruj na adres poniżej.'
    ),
  ];

  static const List<(String, String)> _en = [
    (
      'Account & data we store',
      'The app requires an account (email and password) to use it. Your '
          'email and hashed password, along with session history, freediving '
          'logs, custom presets, and plan settings, are stored on our server '
          'so they follow you across devices. We do not sell or share this '
          'data with third parties, and we do not run any ads or third-party '
          'analytics/tracking tools.'
    ),
    (
      'In-app feedback',
      'Anything you submit via "Report a problem / feedback" is tied to your '
          'account and kept until it has been reviewed — it is not anonymous.'
    ),
    (
      'Your control over your data',
      'You can export your training history (CSV) and permanently delete '
          'your account together with all its server-side data at any time '
          'from Settings.'
    ),
    (
      'Data on your device',
      'The same session history, statistics, planned sessions, custom '
          'presets and settings (including your profile name) are also stored '
          'locally on your device for fast offline access. Uninstalling the '
          'app deletes the local copy — data on the server remains until you '
          'delete your account.'
    ),
    (
      'Notifications',
      'Local reminders are scheduled on the device and require no internet. '
          'If you enable push notifications, your device token is registered '
          'on the server so we can deliver a reminder or announcement to it.'
    ),
    (
      'Permissions',
      'We only use: notifications (reminders), vibration (in-session haptics) '
          'and exact alarm (to fire a planned-session reminder at the right '
          'time). We do not use location, contacts, camera or microphone.'
    ),
    (
      'No ads or tracking',
      'The app contains no advertising and no third-party analytics or '
          'tracking tools.'
    ),
    (
      'Children',
      'The app is not directed at children and does not knowingly collect any '
          'data from anyone under 13.'
    ),
    (
      'Health & safety',
      'Breathing techniques (including hyperventilation and breath holds) can '
          'cause dizziness or fainting. Practice in a safe position, never in '
          'water or while driving. The app is educational and does not replace '
          'medical advice.'
    ),
    (
      'Changes',
      'We may update this policy. The new version will be available in the '
          'app. Questions can be sent to the address below.'
    ),
  ];
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body});
  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: const TextStyle(
              color: AppTheme.textDim, fontSize: 14, height: 1.55),
        ),
      ],
    );
  }
}
