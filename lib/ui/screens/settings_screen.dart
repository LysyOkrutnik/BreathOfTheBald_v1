import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okrutnik_breath/config/l10n.dart';
import 'package:okrutnik_breath/config/responsive.dart';
import 'package:okrutnik_breath/config/theme.dart';
import 'package:okrutnik_breath/config/transitions.dart';
import 'package:okrutnik_breath/logic/providers/data_providers.dart';
import 'package:okrutnik_breath/logic/providers/locale_provider.dart';
import 'package:okrutnik_breath/logic/providers/settings_provider.dart';
import 'package:okrutnik_breath/ui/screens/instruction_screen.dart';
import 'package:okrutnik_breath/ui/screens/privacy_screen.dart';
import 'package:okrutnik_breath/ui/widgets/app_background.dart';
import 'package:okrutnik_breath/ui/widgets/glass_card.dart';
import 'package:okrutnik_breath/ui/widgets/glow_halo.dart';
import 'package:okrutnik_breath/ui/widgets/screen_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final profile = ref.watch(userProfileProvider).value;
    final isPl = ref.watch(localeProvider).languageCode == 'pl';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isTablet ? 640 : 560),
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
                            onEdit: () => _editName(context, ref, settings.profileName),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          _SectionHeader(L10n.get(context, 'settings_section_sound')),
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

                          _SectionHeader(L10n.get(context, 'settings_section_language')),
                          _Group(children: [
                            _Tile(
                              icon: Icons.language_rounded,
                              title: L10n.get(context, 'settings_section_language'),
                              trailing: _LangToggle(
                                isPl: isPl,
                                onTap: () =>
                                    ref.read(localeProvider.notifier).toggleLocale(),
                              ),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),

                          _SectionHeader(L10n.get(context, 'settings_section_about')),
                          _Group(children: [
                            _Tile(
                              icon: Icons.spa_outlined,
                              title: L10n.get(context, 'settings_guide'),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () => Navigator.of(context).push(
                                  fadeThroughRoute(const InstructionScreen())),
                            ),
                            _Tile(
                              icon: Icons.privacy_tip_outlined,
                              title: L10n.get(context, 'settings_privacy'),
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38),
                              onTap: () => Navigator.of(context)
                                  .push(fadeThroughRoute(const PrivacyScreen())),
                            ),
                            _Tile(
                              icon: Icons.info_outline_rounded,
                              title: L10n.get(context, 'settings_version'),
                              trailing: const Text(_appVersion,
                                  style: TextStyle(color: AppTheme.textDim)),
                            ),
                          ]),
                        ].animate(interval: 50.ms).fadeIn(duration: AppMotion.medium),
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

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _NameEditDialog(initial: current),
    );
    if (saved != null) ref.read(settingsProvider.notifier).setProfileName(saved);
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF141C24),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withAlpha(28)),
        ),
        child: Column(
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
              style: const TextStyle(color: AppTheme.textLight),
              cursorColor: AppTheme.primary,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: L10n.get(context, 'settings_name_hint'),
                hintStyle: const TextStyle(color: AppTheme.textDim),
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
        ),
      ),
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
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600),
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
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textDim, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: AppTheme.textLight, fontSize: 14)),
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
                style: const TextStyle(color: AppTheme.textLight, fontSize: 14)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
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
    Widget chip(String label, bool active) => Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
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
      child: Container(
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

