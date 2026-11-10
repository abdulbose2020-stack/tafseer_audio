import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/islamic_pattern.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PlayerScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _PlayerTopBar(
                onClose: () {
                  Navigator.of(context).pop();
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                    AppSpacing.screenPadding,
                    AppSpacing.xl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          const _PlayerMedallion(),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Surah Al-Fatihah',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'الفاتحة',
                            textDirection: TextDirection.rtl,
                            style: AppTypography.arabic(
                              fontSize: 48,
                              weight: 700,
                              color: AppColors.emerald,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'The Opening  •  7 Ayahs  •  Makki',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const _SampleBadge(),
                          const SizedBox(height: AppSpacing.xl),
                          const _StaticSeekBar(),
                          const SizedBox(height: AppSpacing.lg),
                          const _TransportPreview(),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Playback controls will be connected in Phase 3.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to Surah list'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            tooltip: 'Close player',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          Expanded(
            child: Text(
              'Now playing',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _PlayerMedallion extends StatelessWidget {
  const _PlayerMedallion();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      height: 244,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.emerald, AppColors.emeraldDark],
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IslamicPattern(
              color: AppColors.gold,
              opacity: 0.16,
              spacing: 42,
            ),
          ),
          const Center(child: BrandMark(size: 126)),
        ],
      ),
    );
  }
}

class _SampleBadge extends StatelessWidget {
  const _SampleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            size: 16,
            color: AppColors.goldDeep,
          ),
          const SizedBox(width: 6),
          Text(
            'Sample audio',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.goldDeep),
          ),
        ],
      ),
    );
  }
}

class _StaticSeekBar extends StatelessWidget {
  const _StaticSeekBar();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(value: 0, minHeight: 4),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0:00',
              style: textTheme.labelSmall?.copyWith(color: AppColors.muted),
            ),
            Text(
              '--:--',
              style: textTheme.labelSmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransportPreview extends StatelessWidget {
  const _TransportPreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.skip_previous_rounded,
          size: 36,
          color: AppColors.muted,
        ),
        const SizedBox(width: AppSpacing.xl),
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 46,
            color: AppColors.white,
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        const Icon(Icons.skip_next_rounded, size: 36, color: AppColors.muted),
      ],
    );
  }
}
