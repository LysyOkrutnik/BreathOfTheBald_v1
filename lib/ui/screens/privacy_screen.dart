import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// In-app privacy policy. The app is fully offline (no network, accounts, ads or
/// analytics), so the policy is short and concrete. Text is inlined per-locale
/// rather than living in the l10n map because it is long-form legal copy.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _contact = 'rafalcharciarek@gmail.com';

  @override
  Widget build(BuildContext context) {
    final isPl = Localizations.localeOf(context).languageCode == 'pl';
    final sections = isPl ? _pl : _en;
    final updated = isPl ? 'Ostatnia aktualizacja: lipiec 2026'
                         : 'Last updated: July 2026';

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
      'Zero zbierania danych',
      'Aplikacja działa w 100% offline. Nie zbieramy, nie wysyłamy ani nie '
          'udostępniamy żadnych danych osobowych. Nie ma kont, logowania ani '
          'serwerów — nic nie opuszcza Twojego telefonu.'
    ),
    (
      'Dane na urządzeniu',
      'Historia sesji, statystyki, zaplanowane sesje, własne presety oraz '
          'ustawienia (w tym nazwa profilu) są zapisywane wyłącznie lokalnie na '
          'Twoim urządzeniu. Odinstalowanie aplikacji trwale usuwa te dane.'
    ),
    (
      'Powiadomienia',
      'Przypomnienia są planowane lokalnie na urządzeniu. Nie wymagają '
          'internetu i nie przesyłają żadnych informacji na zewnątrz.'
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
      'No data collection',
      'The app is fully offline. We do not collect, transmit or share any '
          'personal data. There are no accounts, logins or servers — nothing '
          'leaves your phone.'
    ),
    (
      'Data on your device',
      'Session history, statistics, planned sessions, custom presets and '
          'settings (including your profile name) are stored only locally on '
          'your device. Uninstalling the app permanently deletes this data.'
    ),
    (
      'Notifications',
      'Reminders are scheduled locally on the device. They require no internet '
          'and send no information anywhere.'
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
