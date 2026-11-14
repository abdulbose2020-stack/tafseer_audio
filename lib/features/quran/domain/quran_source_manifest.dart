/// Version, attribution, and notice metadata for the bundled Qur'an dataset.
///
/// The values are read from `assets/data/quran/manifest.json`; they are not
/// duplicated in the UI so that required notices always match the data that
/// ships with the app.
class QuranSourceManifest {
  const QuranSourceManifest({
    required this.schemaVersion,
    required this.datasetVersion,
    required this.generatedAtUtc,
    required this.surahCount,
    required this.ayahCount,
    required this.arabic,
    required this.english,
    this.catalogue,
  });

  factory QuranSourceManifest.fromJson(Map<String, dynamic> json) {
    final sources = _readObject(json, 'sources');
    final totals = _readObject(json, 'totals');
    final surahCount = _readInt(totals, 'surahs');
    final ayahCount = _readInt(totals, 'ayahs');

    if (surahCount < 1) {
      throw FormatException(
        'Expected a positive Surah count, got $surahCount.',
      );
    }
    if (ayahCount < 1) {
      throw FormatException('Expected a positive Ayah count, got $ayahCount.');
    }

    return QuranSourceManifest(
      schemaVersion: _readString(json, 'schema_version'),
      datasetVersion: _readString(json, 'dataset_version'),
      generatedAtUtc: _readString(json, 'generated_at_utc'),
      surahCount: surahCount,
      ayahCount: ayahCount,
      arabic: QuranArabicSource.fromJson(_readObject(sources, 'arabic')),
      english: QuranEnglishSource.fromJson(_readObject(sources, 'english')),
      catalogue: sources['catalogue'] == null
          ? null
          : QuranCatalogueSource.fromJson(_readObject(sources, 'catalogue')),
    );
  }

  final String schemaVersion;
  final String datasetVersion;
  final String generatedAtUtc;
  final int surahCount;
  final int ayahCount;
  final QuranArabicSource arabic;
  final QuranEnglishSource english;

  /// Catalogue attribution, or null when the manifest predates the
  /// `sources.catalogue` entry.
  final QuranCatalogueSource? catalogue;
}

/// Attribution and required notice for the Arabic Qur'an text.
class QuranArabicSource {
  const QuranArabicSource({
    required this.name,
    required this.provider,
    required this.version,
    required this.releaseDate,
    required this.copyright,
    required this.license,
    required this.notice,
  });

  factory QuranArabicSource.fromJson(Map<String, dynamic> json) {
    return QuranArabicSource(
      name: _readString(json, 'name'),
      provider: _readString(json, 'provider'),
      version: _readString(json, 'version'),
      releaseDate: _readString(json, 'release_date'),
      copyright: _readString(json, 'copyright'),
      license: _readString(json, 'license'),
      notice: _readString(json, 'notice'),
    );
  }

  final String name;
  final String provider;
  final String version;
  final String releaseDate;
  final String copyright;
  final String license;

  /// The complete copyright and licence block from the source.
  final String notice;
}

/// Attribution, version, and required notices for the English translation.
class QuranEnglishSource {
  const QuranEnglishSource({
    required this.name,
    required this.provider,
    required this.publisher,
    required this.attribution,
    required this.version,
    required this.revision,
    required this.lastUpdateUtc,
    required this.license,
    required this.licenseUrl,
    required this.licenseTerms,
    required this.sourceInfoBlock,
  });

  factory QuranEnglishSource.fromJson(Map<String, dynamic> json) {
    return QuranEnglishSource(
      name: _readString(json, 'name'),
      provider: _readString(json, 'provider'),
      publisher: _readString(json, 'publisher'),
      attribution: _readString(json, 'attribution'),
      version: _readString(json, 'version'),
      revision: _readString(json, 'revision'),
      lastUpdateUtc: _readString(json, 'last_update_utc'),
      license: _readString(json, 'license'),
      licenseUrl: _readString(json, 'license_url'),
      licenseTerms: _readString(json, 'license_terms'),
      sourceInfoBlock: _readString(json, 'source_info_block'),
    );
  }

  final String name;
  final String provider;
  final String publisher;

  /// The exact required attribution, including the publisher and source.
  final String attribution;
  final String version;
  final String revision;
  final String lastUpdateUtc;
  final String license;
  final String licenseUrl;
  final String licenseTerms;

  /// The complete translation-information block from the source.
  final String sourceInfoBlock;
}

/// Attribution and copyright for the bundled Surah catalogue metadata.
class QuranCatalogueSource {
  const QuranCatalogueSource({
    required this.name,
    required this.url,
    required this.license,
    required this.copyright,
  });

  factory QuranCatalogueSource.fromJson(Map<String, dynamic> json) {
    return QuranCatalogueSource(
      name: _readString(json, 'name'),
      url: _readString(json, 'url'),
      license: _readString(json, 'license'),
      copyright: _readString(json, 'copyright'),
    );
  }

  final String name;
  final String url;
  final String license;
  final String copyright;
}

Map<String, dynamic> _readObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('Expected "$key" to be a JSON object, got $value.');
  }
  return Map<String, dynamic>.from(value);
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Expected "$key" to be an integer, got $value.');
  }
  return value;
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected "$key" to be a non-empty string.');
  }
  return value;
}
