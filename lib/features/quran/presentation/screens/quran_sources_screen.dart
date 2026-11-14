import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../domain/quran_source_manifest.dart';
import '../providers/quran_sources_providers.dart';

/// Source versions and required copyright/licence notices for the Qur'an data.
///
/// The future Qur'an reader should open this same screen through [route] so
/// the acknowledgement stays available from both modules.
class QuranSourcesScreen extends ConsumerWidget {
  const QuranSourcesScreen({super.key});

  static const Key tanzilLinkKey = Key('quran-sources-tanzil-link');
  static const Key quranEncLinkKey = Key('quran-sources-quranenc-link');
  static const Key arabicNoticeKey = Key('quran-sources-arabic-notice');
  static const Key englishInfoKey = Key('quran-sources-english-info');
  static const Key englishTermsKey = Key('quran-sources-english-terms');
  static const Key catalogueLinkKey = Key('quran-sources-catalogue-link');
  static const Key catalogueNoticeKey = Key('quran-sources-catalogue-notice');

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (context) => const QuranSourcesScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifest = ref.watch(quranSourceManifestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sources & Acknowledgements')),
      body: SafeArea(
        child: manifest.when(
          data: (value) => SelectionArea(child: _SourcesBody(manifest: value)),
          loading: () => const _LoadingSources(),
          error: (error, stackTrace) => _SourcesError(
            onRetry: () => ref.invalidate(quranSourceManifestProvider),
          ),
        ),
      ),
    );
  }
}

class _SourcesBody extends StatelessWidget {
  const _SourcesBody({required this.manifest});

  final QuranSourceManifest manifest;

  @override
  Widget build(BuildContext context) {
    final catalogue = manifest.catalogue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.xxl,
      ),
      children: [
        _IntroCard(manifest: manifest),
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('ARABIC QUR’AN'),
        const SizedBox(height: AppSpacing.sm),
        _SourceCard(
          icon: Icons.menu_book_rounded,
          accent: context.appColors.goldStrong,
          title: manifest.arabic.provider,
          subtitle: manifest.arabic.name,
          details: [
            _SourceDetail('Version', manifest.arabic.version),
            _SourceDetail('Release date', manifest.arabic.releaseDate),
            _SourceDetail('Copyright', manifest.arabic.copyright),
            _SourceDetail('Licence', manifest.arabic.license),
          ],
          notices: [
            _SourceNotice(
              label: 'Required copyright and licence notice',
              text: manifest.arabic.notice,
              textKey: QuranSourcesScreen.arabicNoticeKey,
            ),
          ],
          link: 'https://tanzil.net',
          linkKey: QuranSourcesScreen.tanzilLinkKey,
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('ENGLISH TRANSLATION'),
        const SizedBox(height: AppSpacing.sm),
        _SourceCard(
          icon: Icons.translate_rounded,
          accent: context.appColors.accent,
          title: manifest.english.attribution,
          subtitle: manifest.english.name,
          details: [
            _SourceDetail('Version', manifest.english.version),
            _SourceDetail('Revision', manifest.english.revision),
            _SourceDetail('Last updated', manifest.english.lastUpdateUtc),
            _SourceDetail('Licence', manifest.english.license),
          ],
          notices: [
            _SourceNotice(
              label: 'Required translation information',
              text: manifest.english.sourceInfoBlock,
              textKey: QuranSourcesScreen.englishInfoKey,
            ),
            _SourceNotice(
              label: 'Required usage terms',
              text: manifest.english.licenseTerms,
              textKey: QuranSourcesScreen.englishTermsKey,
            ),
          ],
          link: 'https://quranenc.com',
          linkKey: QuranSourcesScreen.quranEncLinkKey,
          secondaryLink: manifest.english.licenseUrl,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (catalogue != null) ...[
          const _SectionLabel('SURAH CATALOGUE'),
          const SizedBox(height: AppSpacing.sm),
          _SourceCard(
            icon: Icons.format_list_numbered_rounded,
            accent: context.appColors.goldStrong,
            title: catalogue.name,
            subtitle:
                'Surah names, numbers, Ayah counts, and revelation place.',
            details: [
              _SourceDetail('Copyright', catalogue.copyright),
              _SourceDetail('Licence', catalogue.license),
            ],
            notices: [
              _SourceNotice(
                label: 'Adaptation',
                text:
                    'Derived from Tanzil Quran Metadata; revelation place is '
                    "normalized from Tanzil's Meccan and Medinan values to "
                    'makki and madani.',
                textKey: QuranSourcesScreen.catalogueNoticeKey,
              ),
            ],
            link: catalogue.url,
            linkKey: QuranSourcesScreen.catalogueLinkKey,
            secondaryLink: 'https://creativecommons.org/licenses/by/3.0/',
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        const _OfflineNote(),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.manifest});

  final QuranSourceManifest manifest;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.gold.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: colors.goldStrong,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source acknowledgements',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'The Qur’an text, English translation, and Surah '
                      'catalogue are bundled for offline use. The versions '
                      'and required notices below come from the dataset '
                      'manifest.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaPill(label: 'Dataset ${manifest.datasetVersion}'),
              _MetaPill(label: '${manifest.surahCount} Surahs'),
              _MetaPill(label: '${_formatNumber(manifest.ayahCount)} Ayahs'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colors.textSecondary,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.notices,
    required this.link,
    required this.linkKey,
    this.secondaryLink,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final List<_SourceDetail> details;
  final List<_SourceNotice> notices;
  final String link;
  final Key linkKey;
  final String? secondaryLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppSpacing.cardBorderRadius,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < details.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _DetailRow(detail: details[index]),
          ],
          for (final notice in notices) ...[
            const SizedBox(height: AppSpacing.md),
            _NoticeBlock(notice: notice),
          ],
          const SizedBox(height: AppSpacing.md),
          _SourceLink(url: link, linkKey: linkKey),
          if (secondaryLink != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _SourceLink(url: secondaryLink!, linkKey: null),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.detail});

  final _SourceDetail detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            detail.label,
            style: textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            detail.value,
            style: textTheme.bodySmall?.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _NoticeBlock extends StatelessWidget {
  const _NoticeBlock({required this.notice});

  final _SourceNotice notice;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notice.label,
          style: textTheme.labelSmall?.copyWith(
            color: colors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            notice.text,
            key: notice.textKey,
            style: textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.url, required this.linkKey});

  final String url;
  final Key? linkKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 18, color: colors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              url,
              key: linkKey,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.accent,
                decoration: TextDecoration.underline,
                decorationColor: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

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
          Icon(Icons.offline_bolt_rounded, color: colors.goldStrong, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'These acknowledgements ship with the app and remain available '
              'offline. No Qur’an content is downloaded at runtime.',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSources extends StatelessWidget {
  const _LoadingSources();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Loading source acknowledgements...',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SourcesError extends StatelessWidget {
  const _SourcesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppSpacing.cardBorderRadius,
              border: Border.all(color: colors.error.withValues(alpha: 0.24)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colors.error,
                  size: 32,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Unable to load source acknowledgements',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The bundled source manifest could not be read. Please try '
                  'again.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceDetail {
  const _SourceDetail(this.label, this.value);

  final String label;
  final String value;
}

class _SourceNotice {
  const _SourceNotice({
    required this.label,
    required this.text,
    required this.textKey,
  });

  final String label;
  final String text;
  final Key textKey;
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
