import 'package:flutter/material.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/legal_section.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

/// In-app terms of use, accepted (server-side, see `/auth/register`'s
/// `acceptedTerms` field) once at registration. Same structure as
/// PrivacyScreen — text inlined per-locale rather than in the l10n map
/// because it's long-form legal copy.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _contact = 'rafalcharciarek@gmail.com';

  @override
  Widget build(BuildContext context) {
    final isPl = Localizations.localeOf(context).languageCode == 'pl';
    final sections = isPl ? _pl : _en;
    const updated = 'Ostatnia aktualizacja: sierpień 2026';
    const updatedEn = 'Last updated: August 2026';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: context.isTablet ? 720 : 560),
                child: Column(
                  children: [
                    ScreenHeader(title: L10n.get(context, 'settings_terms')),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        children: [
                          Text(
                            isPl ? updated : updatedEn,
                            style: TextStyle(
                                color: AppTheme.textDim.withAlpha(180),
                                fontSize: 12),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          for (final s in sections) ...[
                            LegalSection(heading: s.$1, body: s.$2),
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
                                        color: AppTheme.textLight,
                                        fontSize: 13),
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
      'Czym jest ta aplikacja',
      'Breath of the Bald to aplikacja do treningu technik oddechowych '
          '(metoda Wim Hofa, oddychanie skrzynkowe, 4-7-8, ćwiczenia mobilności) '
          'oraz freedivingu (tabele CO2/O2, test PB). Ma charakter edukacyjny i '
          'treningowy — nie jest sprzętem medycznym i nie zastępuje porady '
          'lekarskiej.'
    ),
    (
      'Realne ryzyko zdrowotne',
      'Hiperwentylacja i wstrzymywanie oddechu mogą powodować zawroty głowy, '
          'mrowienie, a w skrajnych przypadkach omdlenie (utrata przytomności '
          'bez ostrzeżenia jest szczególnie niebezpieczna pod wodą). Ćwicz '
          'zawsze w bezpiecznej pozycji, nigdy w wodzie samodzielnie, nigdy '
          'podczas prowadzenia pojazdu czy obsługi maszyn. Jeśli jesteś w '
          'ciąży, masz choroby serca, epilepsję, wysokie/niskie ciśnienie lub '
          'inne przeciwwskazania — skonsultuj się z lekarzem przed użyciem '
          'aplikacji. Korzystasz z technik oddechowych i tabel freedivingowych '
          'na własną odpowiedzialność.'
    ),
    (
      'Konto',
      'Do korzystania z aplikacji potrzebne jest konto. Odpowiadasz za '
          'prawdziwość podanych danych i bezpieczeństwo swojego hasła. Jedno '
          'konto jest przeznaczone dla jednej osoby.'
    ),
    (
      'Zasady korzystania',
      'Nie wolno: podawać się za kogoś innego, zakłócać działania aplikacji '
          'lub jej infrastruktury, ani wykorzystywać kanału zgłoszeń/opinii do '
          'treści niezwiązanych z aplikacją. Za naruszenie tych zasad konto '
          'może zostać zablokowane lub usunięte.'
    ),
    (
      'Brak gwarancji',
      'Aplikacja jest udostępniana "tak jak jest", bez gwarancji '
          'nieprzerwanego działania czy braku błędów. W granicach '
          'dopuszczonych prawem nie odpowiadamy za szkody wynikające z '
          'korzystania z aplikacji, w tym za konsekwencje zdrowotne wykonywania '
          'opisanych w niej technik oddechowych.'
    ),
    (
      'Zmiany regulaminu',
      'Regulamin może się zmieniać — nowa wersja będzie dostępna w aplikacji. '
          'Pytania kieruj na adres poniżej.'
    ),
  ];

  static const List<(String, String)> _en = [
    (
      'What this app is',
      'Breath of the Bald is a training app for breathing techniques (the '
          'Wim Hof method, box breathing, 4-7-8, mobility exercises) and '
          'freediving (CO2/O2 tables, PB test). It is educational/training in '
          'nature — it is not a medical device and does not replace medical '
          'advice.'
    ),
    (
      'Real health risk',
      'Hyperventilation and breath-holding can cause dizziness, tingling, and '
          'in extreme cases fainting (losing consciousness without warning is '
          'especially dangerous underwater). Always practice in a safe '
          'position, never alone in water, never while driving or operating '
          'machinery. If you are pregnant, have a heart condition, epilepsy, '
          'high/low blood pressure, or other contraindications, consult a '
          'doctor before using the app. You use its breathing techniques and '
          'freediving tables at your own risk.'
    ),
    (
      'Account',
      'An account is required to use the app. You are responsible for the '
          'accuracy of the details you provide and for keeping your password '
          'secure. One account is meant for one person.'
    ),
    (
      'Acceptable use',
      "You may not: impersonate someone else, disrupt the app or its "
          "infrastructure, or use the feedback channel for anything unrelated "
          "to the app. Violating these rules may get your account suspended "
          "or deleted."
    ),
    (
      'No warranty',
      'The app is provided "as is", with no guarantee of uninterrupted or '
          'error-free operation. To the extent permitted by law, we are not '
          'liable for damages arising from using the app, including health '
          'consequences of performing the breathing techniques it describes.'
    ),
    (
      'Changes',
      'These terms may change — the new version will be available in the '
          'app. Questions can be sent to the address below.'
    ),
  ];
}
