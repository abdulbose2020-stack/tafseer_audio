import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/quran_manifest_data_source.dart';
import '../../domain/quran_source_manifest.dart';

/// Loads the source acknowledgement metadata from the bundled asset.
final quranManifestDataSourceProvider = Provider<QuranManifestDataSource>((
  ref,
) {
  return const QuranManifestDataSource();
});

/// The source versions and required notices for the offline Qur'an dataset.
///
/// This provider is lazy: the manifest is read only when the acknowledgements
/// screen (or another consumer) is opened.
final quranSourceManifestProvider = FutureProvider<QuranSourceManifest>((ref) {
  return ref.watch(quranManifestDataSourceProvider).loadManifest();
});
