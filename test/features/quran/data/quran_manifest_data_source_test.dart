import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/quran/data/quran_manifest_data_source.dart';

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.json);

  final String json;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
  }
}

const _validManifest = '''
{
  "schema_version": "1.0.0",
  "dataset_version": "1.0.0",
  "generated_at_utc": "2026-11-13T16:48:38Z",
  "sources": {
    "arabic": {
      "name": "Tanzil Quran Text (Uthmani, Version 1.1)",
      "provider": "Tanzil Project",
      "version": "1.1",
      "release_date": "2021-02-12",
      "copyright": "Copyright (C) 2007-2026 Tanzil Project",
      "license": "Creative Commons Attribution 3.0",
      "notice": "full Arabic notice"
    },
    "english": {
      "name": "QuranEnc English translation (english_saheeh)",
      "provider": "QuranEnc",
      "publisher": "Noor International Center",
      "attribution": "Noor International Center, through QuranEnc.",
      "version": "1.1.2",
      "revision": "v1.1.2-csv.1",
      "last_update_utc": "2025-06-24T13:37:27Z",
      "license": "QuranEnc Terms and Policies",
      "license_url": "https://quranenc.com/en/home/about",
      "license_terms": "full usage terms",
      "source_info_block": "full translation information"
    }
  },
  "totals": {"surahs": 114, "ayahs": 6236}
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the exact versions and notices from the bundled manifest',
    () async {
      final manifest = await const QuranManifestDataSource().loadManifest();

      expect(manifest.schemaVersion, '1.0.0');
      expect(manifest.datasetVersion, '1.0.0');
      expect(manifest.surahCount, 114);
      expect(manifest.ayahCount, 6236);

      expect(manifest.arabic.provider, 'Tanzil Project');
      expect(manifest.arabic.version, '1.1');
      expect(manifest.arabic.releaseDate, '2021-02-12');
      expect(
        manifest.arabic.copyright,
        'Copyright (C) 2007-2026 Tanzil Project',
      );
      expect(manifest.arabic.license, 'Creative Commons Attribution 3.0');
      expect(
        manifest.arabic.notice,
        contains('PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK'),
      );
      expect(manifest.arabic.notice, contains('CHANGING IT IS NOT ALLOWED'));
      expect(manifest.arabic.notice, contains('a link is made to tanzil.net'));

      expect(
        manifest.english.attribution,
        'Noor International Center, through QuranEnc.',
      );
      expect(manifest.english.version, '1.1.2');
      expect(manifest.english.revision, 'v1.1.2-csv.1');
      expect(manifest.english.lastUpdateUtc, '2025-06-24T13:37:27Z');
      expect(manifest.english.license, 'QuranEnc Terms and Policies');
      expect(
        manifest.english.sourceInfoBlock,
        contains("PLEASE DON'T REMOVE THIS IMPORTANT INFORMATION!"),
      );
      expect(
        manifest.english.licenseTerms,
        contains('No modification, addition, or deletion of the content.'),
      );
    },
  );

  test('parses a valid manifest without altering notice text', () async {
    final source = QuranManifestDataSource(
      assetPath: 'test.json',
      bundle: _StringAssetBundle(_validManifest),
    );

    final manifest = await source.loadManifest();

    expect(manifest.surahCount, 114);
    expect(manifest.arabic.notice, 'full Arabic notice');
    expect(manifest.english.sourceInfoBlock, 'full translation information');
    expect(manifest.english.licenseTerms, 'full usage terms');
  });

  test('rejects a document that is not a JSON object', () async {
    final source = QuranManifestDataSource(
      assetPath: 'test.json',
      bundle: _StringAssetBundle('[]'),
    );

    expect(source.loadManifest(), throwsA(isA<FormatException>()));
  });

  test('rejects a manifest without source metadata', () async {
    final source = QuranManifestDataSource(
      assetPath: 'test.json',
      bundle: _StringAssetBundle(
        '{"schema_version": "1.0.0", "dataset_version": "1.0.0", '
        '"generated_at_utc": "2026-11-13T16:48:38Z", '
        '"totals": {"surahs": 114, "ayahs": 6236}}',
      ),
    );

    expect(source.loadManifest(), throwsA(isA<FormatException>()));
  });

  test('rejects an empty required source field', () async {
    final source = QuranManifestDataSource(
      assetPath: 'test.json',
      bundle: _StringAssetBundle(
        _validManifest.replaceFirst('"version": "1.1"', '"version": "  "'),
      ),
    );

    expect(source.loadManifest(), throwsA(isA<FormatException>()));
  });
}
