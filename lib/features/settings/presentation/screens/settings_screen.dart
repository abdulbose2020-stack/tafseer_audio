import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../quran/presentation/screens/quran_sources_screen.dart';
import '../providers/theme_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const Key themeSelectorKey = Key('settings-theme-selector');
  static const Key quranSourcesKey = Key('settings-quran-sources');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.screenPadding,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'APPEARANCE',
              style: textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Semantics(
                  label: 'Theme mode',
                  child: Wrap(
                    key: themeSelectorKey,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final option in _ThemeOption.values)
                        ChoiceChip(
                          key: ValueKey('settings-theme-${option.mode.name}'),
                          label: Text(option.label),
                          selected: themeMode == option.mode,
                          showCheckmark: false,
                          onSelected: (_) {
                            unawaited(
                              ref
                                  .read(themeModeControllerProvider.notifier)
                                  .setThemeMode(option.mode),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'SOURCES & ACKNOWLEDGEMENTS',
              style: textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: quranSourcesKey,
                onTap: () {
                  Navigator.of(context).push(QuranSourcesScreen.route());
                },
                leading: Icon(
                  Icons.verified_user_rounded,
                  color: colors.goldStrong,
                ),
                title: const Text('Qur’an sources'),
                subtitle: Text(
                  'Tanzil Arabic text and Surah metadata; QuranEnc English '
                  'translation.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ThemeOption {
  light(ThemeMode.light, 'Light'),
  dark(ThemeMode.dark, 'Dark'),
  system(ThemeMode.system, 'System');

  const _ThemeOption(this.mode, this.label);

  final ThemeMode mode;
  final String label;
}
