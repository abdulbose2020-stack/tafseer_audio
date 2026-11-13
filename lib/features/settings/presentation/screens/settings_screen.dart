import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../providers/theme_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const Key themeSelectorKey = Key('settings-theme-selector');

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
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Choose how the app looks. Your selection is saved on '
                      'this device and applies to both modules.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      label: 'Theme mode',
                      child: Wrap(
                        key: themeSelectorKey,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final option in _ThemeOption.values)
                            ChoiceChip(
                              key: ValueKey(
                                'settings-theme-${option.mode.name}',
                              ),
                              label: Text(option.label),
                              selected: themeMode == option.mode,
                              showCheckmark: false,
                              onSelected: (_) {
                                unawaited(
                                  ref
                                      .read(
                                        themeModeControllerProvider.notifier,
                                      )
                                      .setThemeMode(option.mode),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(
                          Icons.brightness_auto_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'System follows your device appearance setting.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'ABOUT',
              style: textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.menu_book_rounded,
                      color: colors.accent,
                    ),
                    title: const Text('Qur’an reading'),
                    subtitle: Text(
                      'Arabic text and English translation are being prepared.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  ListTile(
                    leading: Icon(
                      Icons.headphones_rounded,
                      color: colors.accent,
                    ),
                    title: const Text('Tafseer audio'),
                    subtitle: Text(
                      'The 114-Surah catalogue is available. Recordings will '
                      'appear as they are bundled.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  ListTile(
                    leading: Icon(
                      Icons.offline_bolt_rounded,
                      color: colors.goldStrong,
                    ),
                    title: Text(AppConstants.appName),
                    subtitle: Text(
                      'Offline by design. No account, network, or analytics.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
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
