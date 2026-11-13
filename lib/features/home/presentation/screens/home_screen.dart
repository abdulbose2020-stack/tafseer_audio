import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../player/presentation/widgets/mini_player.dart';
import '../../../quran/presentation/screens/quran_reading_placeholder_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../surahs/presentation/screens/surah_list_screen.dart';

/// The two-module entry point for the application.
///
/// Reading and Tafseer Audio remain separate journeys; this screen only
/// provides their entry points and a settings shortcut.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Key readingCardKey = Key('home-reading-card');
  static const Key tafseerCardKey = Key('home-tafseer-card');
  static const Key settingsKey = Key('home-settings');

  void _openReading(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const QuranReadingPlaceholderScreen(),
      ),
    );
  }

  void _openTafseer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const SurahListScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        bottomNavigationBar: const MiniPlayer(),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _HomeHeader(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.xl,
                AppSpacing.screenPadding,
                AppSpacing.xxl + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a module',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Reading and listening stay separate, so each experience '
                    'can be focused and simple.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ModuleCard(
                    actionKey: readingCardKey,
                    icon: Icons.menu_book_rounded,
                    accent: colors.goldStrong,
                    eyebrow: 'QUR’AN READING',
                    title: 'Read the Qur’an',
                    description:
                        'Arabic text and English translation will live here, '
                        'with bookmarks and a saved reading position.',
                    status: 'CONTENT BEING PREPARED',
                    onTap: () => _openReading(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ModuleCard(
                    actionKey: tafseerCardKey,
                    icon: Icons.headphones_rounded,
                    accent: colors.accent,
                    eyebrow: 'TAFSEER AUDIO',
                    title: 'Listen to Tafseer',
                    description:
                        'Open the complete 114-Surah catalogue and the local '
                        'audio player for recorded tafsir.',
                    status: 'CATALOGUE READY',
                    onTap: () => _openTafseer(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SettingsEntry(onTap: () => _openSettings(context)),
                  const SizedBox(height: AppSpacing.lg),
                  const _OfflineNote(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.headerStart, colors.headerEnd],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IslamicPattern(
              color: colors.gold,
              opacity: 0.13,
              spacing: 58,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              topInset + AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandMark(size: 50),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: textTheme.titleLarge?.copyWith(
                              color: colors.onBrand,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Read  •  Listen  •  Reflect',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onBrand.withValues(alpha: 0.7),
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.onBrand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colors.onBrand.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.offline_bolt_rounded,
                            size: 14,
                            color: colors.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'OFFLINE',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onBrand,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppConstants.appNameArabic,
                  textDirection: TextDirection.rtl,
                  style: AppTypography.arabic(
                    fontSize: 34,
                    weight: 700,
                    color: colors.gold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A quiet home for Qur’an reading and tafsir audio.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.onBrand.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.actionKey,
    required this.icon,
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.status,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final Color accent;
  final String eyebrow;
  final String title;
  final String description;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$title. $description',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: actionKey,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: textTheme.labelSmall?.copyWith(
                          color: accent,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(title, style: textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status,
                          style: textTheme.labelSmall?.copyWith(
                            color: accent,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: colors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: HomeScreen.settingsKey,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Icon(
            Icons.settings_rounded,
            color: colors.textSecondary,
            size: 21,
          ),
        ),
        title: const Text('Settings'),
        subtitle: Text(
          'Appearance and application preferences',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: colors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Offline by design. No account, no network, and no analytics.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
