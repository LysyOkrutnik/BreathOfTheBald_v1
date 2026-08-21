import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/core/sync/sync_api_client.dart';
import 'package:okrutnik_breath/core/sync/sync_service.dart';
import 'package:okrutnik_breath/logic/providers/app_info_provider.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/locale_provider.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/logic/providers/sync_providers.dart';
import 'package:okrutnik_breath/logic/wimhof/wimhof_progression.dart';
import 'package:okrutnik_breath/ui/screens/auth_gate_screen.dart';
import 'package:okrutnik_breath/ui/screens/privacy_screen.dart';
import 'package:okrutnik_breath/ui/screens/terms_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/confirm_dialog.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/glow_halo.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';
import 'package:okrutnik_breath/ui/widgets/section_header.dart';
import 'package:okrutnik_breath/ui/widgets/week_preferences_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _contactEmail = 'rafalcharciarek@gmail.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final profile = ref.watch(userProfileProvider).value;
    final isPl = ref.watch(localeProvider).languageCode == 'pl';
    final appVersion = ref.watch(appVersionProvider).value ?? '';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: context.isTablet ? 640 : 560),
                child: Column(
                  children: [
                    ScreenHeader(title: L10n.get(context, 'settings_title')),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        children: [
                          _ProfileHeader(
                            name: settings.profileName,
                            level: profile?.level ?? 1,
                            streak: profile?.dailyStreak ?? 0,
                            onEdit: () =>
                                _editName(context, ref, settings.profileName),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SectionHeader(
                              L10n.get(context, 'settings_section_account')),
                          const _AccountSection(),
                          const SizedBox(height: AppSpacing.lg),
                          SectionHeader(
                              L10n.get(context, 'settings_section_reminders')),
                          _Group(children: [
                            _SwitchTile(
                              icon: Icons.notifications_active_outlined,
                              title:
                                  L10n.get(context, 'settings_daily_reminder'),
                              value: settings.dailyReminderEnabled,
                              onChanged: (v) =>
                                  _setDailyReminder(context, ref, v),
                            ),
                            _Tile(
                              icon: Icons.event_available_outlined,
                              title: L10n.get(context, 'settings_availability'),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () => WeekPreferencesSheet.show(context),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.xs),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm),
                            child: Text(
                              L10n.get(context, 'settings_daily_reminder_note'),
                              style: TextStyle(
                                  color: AppTheme.textDim.withAlpha(180),
                                  fontSize: 11,
                                  height: 1.3),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SectionHeader(
                              L10n.get(context, 'settings_section_sound')),
                          _Group(children: [
                            _SwitchTile(
                              icon: Icons.volume_up_rounded,
                              title: L10n.get(context, 'settings_sound'),
                              value: settings.soundEnabled,
                              onChanged: notifier.setSound,
                            ),
                            _SwitchTile(
                              icon: Icons.vibration_rounded,
                              title: L10n.get(context, 'settings_haptics'),
                              value: settings.hapticsEnabled,
                              onChanged: notifier.setHaptics,
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          SectionHeader(
                              L10n.get(context, 'settings_section_language')),
                          _Group(children: [
                            _Tile(
                              icon: Icons.language_rounded,
                              title: L10n.get(
                                  context, 'settings_section_language'),
                              trailing: _LangToggle(
                                isPl: isPl,
                                onTap: () => ref
                                    .read(localeProvider.notifier)
                                    .toggleLocale(),
                              ),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          SectionHeader(
                              L10n.get(context, 'settings_section_help')),
                          _Group(children: [
                            _Tile(
                              icon: Icons.widgets_outlined,
                              title: L10n.get(context, 'settings_home_widget'),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () => _showHomeWidgetInfo(context),
                            ),
                            _Tile(
                              icon: Icons.mail_outline_rounded,
                              title: L10n.get(context, 'settings_contact'),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () => _contactSupport(context),
                            ),
                            _Tile(
                              icon: Icons.bug_report_outlined,
                              title: L10n.get(context, 'settings_feedback'),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () => _reportFeedback(context, ref),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          SectionHeader(
                              L10n.get(context, 'settings_section_about')),
                          _Group(children: [
                            _Tile(
                              icon: Icons.privacy_tip_outlined,
                              title: L10n.get(context, 'settings_privacy'),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () => Navigator.of(context).push(
                                  fadeThroughRoute(const PrivacyScreen())),
                            ),
                            _Tile(
                              icon: Icons.gavel_outlined,
                              title: L10n.get(context, 'settings_terms'),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () => Navigator.of(context)
                                  .push(fadeThroughRoute(const TermsScreen())),
                            ),
                            _Tile(
                              icon: Icons.info_outline_rounded,
                              title: L10n.get(context, 'settings_version'),
                              trailing: Text(appVersion,
                                  style:
                                      const TextStyle(color: AppTheme.textDim)),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          SectionHeader(
                              L10n.get(context, 'settings_section_advanced')),
                          _Group(children: [
                            _Tile(
                              icon: Icons.tune_rounded,
                              title: L10n.get(
                                  context, 'settings_advanced_thresholds'),
                              trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () =>
                                  _showAdvancedThresholdsDialog(context, ref),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          SectionHeader(
                              L10n.get(context, 'settings_section_danger')),
                          _Group(children: [
                            _Tile(
                              icon: Icons.restart_alt_rounded,
                              title:
                                  L10n.get(context, 'settings_reset_progress'),
                              color: AppTheme.danger,
                              trailing: Icon(Icons.chevron_right_rounded,
                                  color: AppTheme.danger.withAlpha(160)),
                              onTap: () => _resetProgress(context, ref),
                            ),
                          ]),
                        ]
                            .animate(interval: 50.ms)
                            .fadeIn(duration: AppMotion.medium),
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

  Future<void> _setDailyReminder(
      BuildContext context, WidgetRef ref, bool enable) async {
    final title = L10n.get(context, 'notif_reminder_title');
    final body = L10n.get(context, 'notif_reminder_body');
    final permissionDenied =
        L10n.get(context, 'settings_notif_permission_denied');
    final messenger = ScaffoldMessenger.of(context);

    if (enable) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        messenger.showSnackBar(SnackBar(content: Text(permissionDenied)));
        return;
      }
    }

    await ref.read(settingsProvider.notifier).setDailyReminderEnabled(
          enable,
          title: title,
          body: body,
        );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final saved = await showGlassDialog<String>(
      context,
      builder: (_) => _NameEditDialog(initial: current),
    );
    if (saved != null) {
      ref.read(settingsProvider.notifier).setProfileName(saved);
    }
  }

  Future<void> _contactSupport(BuildContext context) async {
    final subject = L10n.get(context, 'settings_contact_subject');
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    final messenger = ScaffoldMessenger.of(context);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      messenger.showSnackBar(SnackBar(
          content: Text(L10n.get(context, 'settings_contact_failed'))));
    }
  }

  /// Wipes Sessions/FreedivingSessionLog and resets level/XP/streak, PB, and
  /// the Wim Hof ladder back to their starting state — a fresh start, not a
  /// logout. Custom presets (user-authored content, not progress) and the
  /// freediving safety consent (a one-time acknowledgment, not progress)
  /// are deliberately left untouched.
  Future<void> _resetProgress(BuildContext context, WidgetRef ref) async {
    // A logged-in user's reset gets pushed by the next sync (resetting
    // FreedivingProfile/WimHofProgress also bumps ProfileSyncMarker, so it's
    // treated as a genuine, newer change) — the confirmation must say so, or
    // "reset progress" silently becomes a server-side data-loss event too,
    // with nothing in the dialog hinting at that beyond "local" progress.
    final isSyncing = await ref.read(authServiceProvider).isLoggedIn;
    if (!context.mounted) return;

    final confirmed = await showGlassDialog<bool>(
      context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.danger, size: 34),
          const SizedBox(height: AppSpacing.lg),
          Text(
            L10n.get(context, 'settings_reset_progress_confirm_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            L10n.get(context, 'settings_reset_progress_confirm_body'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          if (isSyncing) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              L10n.get(context, 'settings_reset_progress_confirm_sync_note'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.danger, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(L10n.get(context, 'common_cancel'),
                      style: const TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                      L10n.get(context, 'settings_reset_progress_confirm_yes'),
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(sessionRepositoryProvider).deleteAll();
    await ref.read(freedivingRepositoryProvider).resetProgress();
    await ref.read(userProfileRepositoryProvider).resetProgress();
    await ref.read(wimHofRepositoryProvider).resetProgress();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L10n.get(context, 'settings_reset_progress_done'))));
    }
  }

  /// The only inbox for this — reviewed from the /admin panel, there's no
  /// other channel a report or opinion submitted here ends up in.
  Future<void> _reportFeedback(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    String category = 'bug';
    final submitted = await showGlassDialog<bool>(
      context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(L10n.get(context, 'feedback_dialog_title'),
                style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                for (final entry in const [
                  ('bug', 'feedback_category_bug'),
                  ('opinion', 'feedback_category_opinion'),
                  ('other', 'feedback_category_other'),
                ]) ...[
                  if (entry.$1 != 'bug') const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _CategoryChip(
                      label: L10n.get(context, entry.$2),
                      selected: category == entry.$1,
                      onTap: () => setDialogState(() => category = entry.$1),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 2000,
              style: const TextStyle(color: AppTheme.textLight),
              cursorColor: AppTheme.primary,
              decoration: InputDecoration(
                hintText: L10n.get(context, 'feedback_message_hint'),
                hintStyle: const TextStyle(color: AppTheme.textDim),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(L10n.get(context, 'common_cancel'),
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(L10n.get(context, 'feedback_submit')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final message = controller.text.trim();
    controller.dispose();
    if (submitted != true || message.isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final sentText = L10n.get(context, 'feedback_sent');
    final errorText = L10n.get(context, 'feedback_error');
    try {
      await ref
          .read(syncApiClientProvider)
          .submitFeedback(category: category, message: message);
      messenger.showSnackBar(SnackBar(content: Text(sentText)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(errorText)));
    }
  }

  Future<void> _showAdvancedThresholdsDialog(
      BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final detrainingController = TextEditingController(
        text:
            '${settings.detrainingDaysOverride ?? kDetrainingDays}');
    final weeklyCapController = TextEditingController(
        text: '${settings.weeklyHardCapOverride ?? kWeeklyHardSessionCap}');
    final pbCautionController = TextEditingController(
        text:
            '${settings.pbCautionRatioOverride ?? kPbCautionRetentionRatio}');
    final maxRpeController = TextEditingController(
        text: '${settings.maxAvgRpeToAdvanceOverride ?? kMaxAvgRpeToAdvance}');

    Widget field(TextEditingController controller, String labelKey) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.textLight),
          cursorColor: AppTheme.primary,
          decoration: InputDecoration(
            labelText: L10n.get(context, labelKey),
            labelStyle: const TextStyle(color: AppTheme.textDim),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primary)),
          ),
        ),
      );
    }

    final saved = await showGlassDialog<bool>(
      context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(L10n.get(context, 'settings_advanced_thresholds'),
                style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            Text(L10n.get(context, 'settings_advanced_thresholds_desc'),
                style: const TextStyle(
                    color: AppTheme.textDim, fontSize: 12, height: 1.4)),
            const SizedBox(height: AppSpacing.lg),
            field(detrainingController, 'settings_advanced_detraining_days'),
            field(weeklyCapController, 'settings_advanced_weekly_cap'),
            field(pbCautionController, 'settings_advanced_pb_caution_ratio'),
            field(maxRpeController, 'settings_advanced_max_avg_rpe'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  detrainingController.text = '$kDetrainingDays';
                  weeklyCapController.text = '$kWeeklyHardSessionCap';
                  pbCautionController.text = '$kPbCautionRetentionRatio';
                  maxRpeController.text = '$kMaxAvgRpeToAdvance';
                },
                child: Text(L10n.get(context, 'settings_advanced_reset'),
                    style: const TextStyle(color: AppTheme.textDim)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(L10n.get(context, 'common_cancel'),
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(L10n.get(context, 'common_save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final rawDetraining = int.tryParse(detrainingController.text.trim());
      final detrainingDays = rawDetraining?.clamp(1, 365).toInt();
      final rawWeeklyCap = int.tryParse(weeklyCapController.text.trim());
      final weeklyCap = rawWeeklyCap?.clamp(1, 14).toInt();
      final rawPbCaution = double.tryParse(pbCautionController.text.trim());
      final pbCautionRatio = rawPbCaution?.clamp(0.1, 1.0).toDouble();
      final rawMaxRpe = double.tryParse(maxRpeController.text.trim());
      final maxAvgRpe = rawMaxRpe?.clamp(1.0, 10.0).toDouble();
      await ref.read(settingsProvider.notifier).setAdvancedThresholds(
            detrainingDays: detrainingDays == kDetrainingDays ? null : detrainingDays,
            weeklyHardCap: weeklyCap == kWeeklyHardSessionCap ? null : weeklyCap,
            pbCautionRatio:
                pbCautionRatio == kPbCautionRetentionRatio ? null : pbCautionRatio,
            maxAvgRpeToAdvance:
                maxAvgRpe == kMaxAvgRpeToAdvance ? null : maxAvgRpe,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(L10n.get(context, 'settings_advanced_saved'))));
      }
    }

    detrainingController.dispose();
    weeklyCapController.dispose();
    pbCautionController.dispose();
    maxRpeController.dispose();
  }

  void _showHomeWidgetInfo(BuildContext context) {
    showGlassDialog(
      context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.get(context, 'settings_home_widget'),
            style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            L10n.get(context, 'settings_home_widget_instructions'),
            style: const TextStyle(
                color: AppTheme.textDim, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(L10n.get(context, 'common_ok')),
          ),
        ],
      ),
    );
  }
}

/// Owns its [TextEditingController] for the dialog's lifetime, so dismissing by
/// tapping the barrier disposes it cleanly (the previous inline version disposed
/// the controller across an await gap, crashing on barrier dismiss).
class _NameEditDialog extends StatefulWidget {
  const _NameEditDialog({required this.initial});
  final String initial;

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          L10n.get(context, 'settings_profile_name'),
          style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 24,
          style: const TextStyle(color: AppTheme.textLight),
          cursorColor: AppTheme.primary,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: L10n.get(context, 'settings_name_hint'),
            hintStyle: const TextStyle(color: AppTheme.textDim),
            counterStyle: const TextStyle(color: AppTheme.textDim),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primary)),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(L10n.get(context, 'common_cancel'),
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
                child: Text(L10n.get(context, 'common_save')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Registration/login + sync controls. Deliberately its own small state
/// machine (logged-in-ness and last-synced time are read from secure
/// storage / SharedPreferences, not the reactive Settings state) rather than
/// threading auth state through the whole app — only this section needs it.
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  static const _minPasswordLength = 8;

  // Same deliberately simple check as AuthGateScreen's — good enough to
  // catch a typo before a round trip to the server, not a full validator.
  static final _emailFormatPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool _loading = false;

  bool? _isLoggedIn;
  DateTime? _lastSyncedAt;
  String? _loggedInEmail;
  bool _emailVerified = true;
  bool _resendingVerification = false;

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  Future<void> _refreshState() async {
    final authService = ref.read(authServiceProvider);
    final loggedIn = await authService.isLoggedIn;
    final loggedInEmail = await authService.email;
    var emailVerified = await authService.emailVerified;
    // The cached flag is only ever set at login/register time — verifying
    // via the emailed browser link (server-side, out-of-band) never told
    // this device, so it showed "unverified" forever after a real,
    // successful verification. Re-check with the server whenever we'd
    // otherwise show the nag banner; best-effort, since Settings must still
    // open fine offline.
    if (loggedIn && !emailVerified) {
      try {
        final me = await ref.read(syncApiClientProvider).getMe();
        if (me['emailVerified'] == true) {
          await authService.markEmailVerified();
          emailVerified = true;
        }
      } catch (_) {
        // Offline or a transient error — keep showing the cached value.
      }
    }
    final lastSync = await ref.read(syncServiceProvider).lastSyncedAt;
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _loggedInEmail = loggedInEmail;
      _emailVerified = emailVerified;
      _lastSyncedAt = lastSync;
    });
  }

  Future<void> _sync() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(syncServiceProvider).syncNow();
      if (result.message != null) {
        developer.log('Sync failed: ${result.message}', name: 'SettingsScreen');
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = L10n.get(
          context,
          switch (result.outcome) {
            SyncOutcome.success => 'account_sync_success',
            SyncOutcome.authExpired => 'account_sync_auth_expired',
            _ => 'account_sync_failed',
          });
      // Appending the raw detail on failure — a status code, a timeout, a
      // response body snippet — turns "sync failed" from a dead end into
      // something actually diagnosable, for the one person this app has as
      // a user right now.
      final detail =
          result.outcome == SyncOutcome.success ? null : result.message;

      await _refreshState();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(detail == null ? message : '$message\n$detail'),
        duration: detail == null
            ? const Duration(milliseconds: 4000)
            : const Duration(seconds: 12),
      ));
    } catch (e, st) {
      developer.log('Unexpected error during sync',
          name: 'SettingsScreen', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${L10n.get(context, 'account_sync_failed')}\n$e'),
          duration: const Duration(seconds: 12),
        ));
      }
    } finally {
      // Guaranteed regardless of how the above exits — previously an
      // exception here (from syncNow() or _refreshState()) left `_loading`
      // stuck true forever, permanently disabling the "Sync now" tile with
      // no error shown at all.
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Self-service export — the one thing account deletion didn't already
  /// cover. Written to a temp file and handed to the OS share sheet rather
  /// than saved silently into app-private storage the user can't easily
  /// find afterwards.
  Future<void> _exportData(BuildContext context) async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = await ref.read(syncApiClientProvider).exportData();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/breath-of-the-bald-export.csv');
      await file.writeAsString(csv);
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text(L10n.get(context, 'account_error_network'))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Every logout path ends the same way: back on the mandatory login gate,
  /// not just an inline "logged out" state in Settings — there is no
  /// anonymous mode to fall back into.
  void _goToAuthGate(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
        fadeThroughRoute(const AuthGateScreen()), (route) => false);
  }

  Future<void> _logout(BuildContext context) async {
    // Best-effort: stop push targeting this device before the token that
    // authorizes the unregister call itself is gone.
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await ref.read(syncApiClientProvider).unregisterDevice(fcmToken);
      }
    } catch (_) {
      // Not fatal — logging out locally still happens either way.
    }
    await ref.read(authServiceProvider).logout();
    // Every local row's syncId is permanent — left behind after logout, it
    // would get silently re-pushed and attributed to whichever account
    // logs in next on this device. See AppDatabase.wipeAllLocalData.
    await ref.read(databaseProvider).wipeAllLocalData();
    await ref.read(syncServiceProvider).clearLastSyncedAt();
    if (context.mounted) _goToAuthGate(context);
  }

  Future<void> _resendVerification(BuildContext context) async {
    // The button had no debounce at all — the one account-action tile not
    // gated by `_loading`, so rapid taps could fire unlimited verification
    // emails before the server's own rate limit (just added) catches up.
    if (_resendingVerification) return;
    setState(() => _resendingVerification = true);
    final messenger = ScaffoldMessenger.of(context);
    String resultKey;
    try {
      await ref.read(syncApiClientProvider).resendVerificationEmail();
      resultKey = 'account_verification_sent';
    } on SyncApiException catch (e) {
      resultKey = e.statusCode == 429
          ? 'account_error_too_many_attempts'
          : 'account_error_network';
    } catch (_) {
      resultKey = 'account_error_network';
    }
    if (mounted) setState(() => _resendingVerification = false);
    if (!context.mounted) return;
    messenger
        .showSnackBar(SnackBar(content: Text(L10n.get(context, resultKey))));
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    String? errorKey;
    final changed = await showGlassDialog<bool>(
      context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(L10n.get(context, 'account_change_password_title'),
                style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: currentController,
              autofocus: true,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textLight),
              cursorColor: AppTheme.primary,
              decoration: InputDecoration(
                hintText: L10n.get(context, 'account_current_password_hint'),
                hintStyle: const TextStyle(color: AppTheme.textDim),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: newController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textLight),
              cursorColor: AppTheme.primary,
              decoration: InputDecoration(
                hintText: L10n.get(context, 'account_new_password_hint'),
                hintStyle: const TextStyle(color: AppTheme.textDim),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary)),
              ),
            ),
            if (errorKey != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(L10n.get(context, errorKey!),
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(L10n.get(context, 'common_cancel'),
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (newController.text.length < _minPasswordLength) {
                        setDialogState(() =>
                            errorKey = 'account_error_password_too_short');
                        return;
                      }
                      try {
                        await ref.read(syncApiClientProvider).changePassword(
                              currentPassword: currentController.text,
                              newPassword: newController.text,
                              authService: ref.read(authServiceProvider),
                            );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on SyncApiException catch (e) {
                        setDialogState(() => errorKey = e.statusCode == 401
                            ? 'account_error_invalid_credentials'
                            : 'account_error_unknown');
                      } catch (_) {
                        setDialogState(
                            () => errorKey = 'account_error_network');
                      }
                    },
                    child: Text(
                        L10n.get(context, 'account_change_password_submit')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    currentController.dispose();
    newController.dispose();
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L10n.get(context, 'account_change_password_success'))));
    }
  }

  Future<void> _showChangeEmailDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? errorKey;
    var submitting = false;
    final changed = await showGlassDialog<bool>(
      context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(L10n.get(context, 'account_change_email'),
                style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textLight),
              cursorColor: AppTheme.primary,
              decoration: InputDecoration(
                hintText: L10n.get(context, 'account_new_email_hint'),
                hintStyle: const TextStyle(color: AppTheme.textDim),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textLight),
              cursorColor: AppTheme.primary,
              decoration: InputDecoration(
                hintText: L10n.get(context, 'account_current_password_hint'),
                hintStyle: const TextStyle(color: AppTheme.textDim),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary)),
              ),
            ),
            if (errorKey != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(L10n.get(context, errorKey!),
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(L10n.get(context, 'common_cancel'),
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    // Debounced the same way _resendVerification is — without
                    // this, a double-tap while the first request is still in
                    // flight could fire two change-email calls at once.
                    onPressed: submitting
                        ? null
                        : () async {
                            final newEmail = emailController.text.trim();
                            if (!_emailFormatPattern.hasMatch(newEmail)) {
                              setDialogState(() => errorKey =
                                  'account_error_invalid_email_format');
                              return;
                            }
                            setDialogState(() {
                              submitting = true;
                              errorKey = null;
                            });
                            try {
                              await ref.read(syncApiClientProvider).changeEmail(
                                    newEmail: newEmail,
                                    currentPassword: passwordController.text,
                                    authService: ref.read(authServiceProvider),
                                  );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(true);
                              }
                            } on SyncApiException catch (e) {
                              setDialogState(() {
                                submitting = false;
                                errorKey = switch (e.statusCode) {
                                  401 => 'account_error_invalid_credentials',
                                  409 => 'account_error_email_taken',
                                  _ => 'account_error_unknown',
                                };
                              });
                            } catch (_) {
                              setDialogState(() {
                                submitting = false;
                                errorKey = 'account_error_network';
                              });
                            }
                          },
                    child:
                        Text(L10n.get(context, 'account_change_email_submit')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
    passwordController.dispose();
    if (changed == true && context.mounted) {
      await _refreshState();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L10n.get(context, 'account_change_email_success'))));
    }
  }

  Future<void> _showDevicesDialog(BuildContext context) async {
    // Opens immediately with a loading spinner rather than awaiting
    // listDevices() before the dialog exists at all — the previous version
    // left the whole screen looking frozen for however long that network
    // call took, with no feedback that anything was happening.
    var isLoading = true;
    var devices = <Map<String, dynamic>>[];
    String? loadError;
    String? deleteError;
    // Tracks the one device currently mid-delete, if any — a double-tap on
    // "Usuń" before the first request lands could otherwise fire it twice.
    String? deletingDeviceId;

    await showGlassDialog<void>(
      context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          if (isLoading) {
            ref.read(syncApiClientProvider).listDevices().then((result) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                devices = result;
                isLoading = false;
              });
            }).catchError((_) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                loadError = L10n.get(context, 'account_error_devices_load');
                isLoading = false;
              });
            });
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(L10n.get(context, 'devices_dialog_title'),
                  style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.md),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (loadError != null)
                Text(loadError!,
                    style:
                        const TextStyle(color: AppTheme.danger, fontSize: 12))
              else if (devices.isEmpty)
                Text(L10n.get(context, 'devices_empty'),
                    style:
                        const TextStyle(color: AppTheme.textDim, fontSize: 13))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final device in devices)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (device['label'] as String?) ??
                                        device['id'] as String,
                                    style: const TextStyle(
                                        color: AppTheme.textLight,
                                        fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: deletingDeviceId ==
                                          device['id']
                                      ? null
                                      : () async {
                                          final deviceId =
                                              device['id'] as String;
                                          setDialogState(
                                              () => deletingDeviceId =
                                                  deviceId);
                                          try {
                                            await ref
                                                .read(syncApiClientProvider)
                                                .deleteDevice(deviceId);
                                            setDialogState(() {
                                              devices.remove(device);
                                              deleteError = null;
                                              deletingDeviceId = null;
                                            });
                                          } catch (_) {
                                            setDialogState(() {
                                              deleteError = L10n.get(
                                                  context,
                                                  'account_error_device_delete');
                                              deletingDeviceId = null;
                                            });
                                          }
                                        },
                                  child: Text(
                                      L10n.get(context, 'devices_remove'),
                                      style: const TextStyle(
                                          color: AppTheme.danger,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (deleteError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(deleteError!,
                    style:
                        const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ],
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(L10n.get(context, 'common_ok')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logoutAllDevices(BuildContext context) async {
    final confirmed = await showGlassConfirm(
      context,
      title: L10n.get(context, 'account_logout_all_confirm_title'),
      confirmLabel: L10n.get(context, 'account_logout_all_confirm_yes'),
      cancelLabel: L10n.get(context, 'common_cancel'),
      icon: Icons.phonelink_erase_rounded,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    var remoteLogoutFailed = false;
    try {
      await ref.read(syncApiClientProvider).logoutAllDevices();
    } catch (_) {
      // Even if the server call fails (e.g. offline), clearing the local
      // token below still logs this device out — the "all devices" part
      // just won't have taken effect remotely, so the toast below must say
      // so rather than claiming an unqualified success.
      remoteLogoutFailed = true;
    }
    await ref.read(authServiceProvider).logout();
    // See _logout() — same stale-syncId leak risk applies here.
    await ref.read(databaseProvider).wipeAllLocalData();
    await ref.read(syncServiceProvider).clearLastSyncedAt();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
        content: Text(L10n.get(context,
            remoteLogoutFailed
                ? 'account_logout_all_partial'
                : 'account_logout_all_done'))));
    _goToAuthGate(context);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showGlassDialog<bool>(
      context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.danger, size: 34),
          const SizedBox(height: AppSpacing.lg),
          Text(L10n.get(context, 'account_delete_confirm_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.0)),
          const SizedBox(height: AppSpacing.sm),
          Text(L10n.get(context, 'account_delete_confirm_body'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13, height: 1.4)),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(L10n.get(context, 'common_cancel'),
                      style: const TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(L10n.get(context, 'account_delete_confirm_yes'),
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(syncApiClientProvider).deleteAccount();
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text(L10n.get(context, 'account_error_network'))));
      }
      return;
    }
    await ref.read(authServiceProvider).logout();
    // The account is gone server-side — definitely don't want this device
    // silently re-uploading its history to whatever account logs in next.
    await ref.read(databaseProvider).wipeAllLocalData();
    await ref.read(syncServiceProvider).clearLastSyncedAt();
    if (!context.mounted) return;
    messenger.showSnackBar(
        SnackBar(content: Text(L10n.get(context, 'account_delete_done'))));
    _goToAuthGate(context);
  }

  @override
  Widget build(BuildContext context) {
    // Settings is only reachable once logged in (there's no anonymous mode
    // to fall back into) — null/false here is a brief transient state while
    // _refreshState()'s first read completes, or mid-logout just before this
    // screen navigates away to the auth gate.
    if (_isLoggedIn != true) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context).toString();
    final lastSyncedLabel = _lastSyncedAt == null
        ? L10n.get(context, 'account_never_synced')
        : '${L10n.get(context, 'account_last_synced')} '
            '${DateFormat('dd.MM.yyyy HH:mm', locale).format(_lastSyncedAt!)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loggedInEmail != null)
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.sm, bottom: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined,
                    color: AppTheme.textDim, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _loggedInEmail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textLight, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (!_emailVerified)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined,
                      color: AppTheme.lure, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(L10n.get(context, 'account_email_not_verified'),
                        style: const TextStyle(
                            color: AppTheme.textLight, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: _resendingVerification
                        ? null
                        : () => _resendVerification(context),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(
                        L10n.get(context, 'account_resend_verification'),
                        style: const TextStyle(
                            color: AppTheme.lure, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        _Group(children: [
          _Tile(
            icon: Icons.sync_rounded,
            title: L10n.get(
                context, _loading ? 'account_syncing' : 'account_sync_now'),
            onTap: _loading ? null : _sync,
          ),
          _Tile(
            icon: Icons.password_rounded,
            title: L10n.get(context, 'account_change_password'),
            onTap: _loading ? null : () => _showChangePasswordDialog(context),
          ),
          _Tile(
            icon: Icons.alternate_email_rounded,
            title: L10n.get(context, 'account_change_email'),
            onTap: _loading ? null : () => _showChangeEmailDialog(context),
          ),
          _Tile(
            icon: Icons.devices_other_outlined,
            title: L10n.get(context, 'account_manage_devices'),
            onTap: _loading ? null : () => _showDevicesDialog(context),
          ),
          _Tile(
            icon: Icons.download_outlined,
            title: L10n.get(context, 'account_export_data'),
            onTap: _loading ? null : () => _exportData(context),
          ),
          _Tile(
            icon: Icons.logout_rounded,
            title: L10n.get(context, 'account_logout'),
            onTap: _loading ? null : () => _logout(context),
          ),
          _Tile(
            icon: Icons.phonelink_erase_rounded,
            title: L10n.get(context, 'account_logout_all'),
            onTap: _loading ? null : () => _logoutAllDevices(context),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            lastSyncedLabel,
            style:
                TextStyle(color: AppTheme.textDim.withAlpha(180), fontSize: 11),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Group(children: [
          _Tile(
            icon: Icons.person_remove_outlined,
            title: L10n.get(context, 'account_delete'),
            color: AppTheme.danger,
            trailing: Icon(Icons.chevron_right_rounded,
                color: AppTheme.danger.withAlpha(160)),
            onTap: _loading ? null : () => _deleteAccount(context),
          ),
        ]),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.level,
    required this.streak,
    required this.onEdit,
  });

  final String name;
  final int level;
  final int streak;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final displayName = name.isEmpty ? 'Okrutnik' : name;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          GlowHalo(
            color: AppTheme.primary,
            diameter: 52,
            haloScale: 1.5,
            intensity: 70,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withAlpha(28),
                border: Border.all(color: AppTheme.primary.withAlpha(120)),
              ),
              child: Center(
                child: Text(
                  '$level',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${L10n.get(context, 'stats_streak')}: $streak',
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppTheme.primary, size: 20),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: Colors.white.withAlpha(14), indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Overrides the icon/title color — used for destructive actions (e.g.
  /// "Reset progress"), which otherwise render identically to any neutral
  /// setting despite being irreversible.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppTheme.textDim, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: color ?? AppTheme.textLight, fontSize: 14)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textDim, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(title,
                style:
                    const TextStyle(color: AppTheme.textLight, fontSize: 14)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A single selectable pill in a segmented picker (e.g. feedback category).
/// Deliberately not a [DropdownButton] — that widget pushes its own overlay
/// route internally, which crashes with a `_dependents.isEmpty` assertion
/// when used inside a `BackdropFilter`-based dialog like [showGlassDialog].
class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.black : AppTheme.textDim,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.isPl, required this.onTap});
  final bool isPl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool active) => AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.black : AppTheme.textDim,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // The whole pill toggles the language on one tap — was only ~28dp
      // tall, below the 48dp minimum recommended touch target.
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [chip('PL', isPl), chip('EN', !isPl)],
        ),
      ),
    );
  }
}
