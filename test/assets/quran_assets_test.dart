import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/constants/asset_paths.dart';
import 'package:tafseer_audio/features/quran/data/quran_manifest_data_source.dart';

import 'support/sha256.dart';

Future<Map<String, dynamic>> _loadManifestJson() async {
  final rawJson = await rootBundle.loadString(AssetPaths.quranManifest);
  final decoded = jsonDecode(rawJson);
  expect(
    decoded,
    isA<Map<String, dynamic>>(),
    reason: '${AssetPaths.quranManifest} must contain a JSON object.',
  );
  return decoded as Map<String, dynamic>;
}

/// Reads the manifest entries keyed by Mushaf number after checking their shape.
Map<int, Map<String, dynamic>> _manifestEntriesByNumber(
  Map<String, dynamic> manifest,
) {
  final rawEntries = manifest['surahs'];
  expect(
    rawEntries,
    isA<List<dynamic>>(),
    reason: 'The manifest must contain a "surahs" list.',
  );

  final entries = rawEntries as List<dynamic>;
  expect(entries, hasLength(114));

  final byNumber = <int, Map<String, dynamic>>{};
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    expect(
      entry,
      isA<Map<String, dynamic>>(),
      reason: 'Manifest Surah entry $index must be a JSON object.',
    );
    final map = entry as Map<String, dynamic>;
    final number = map['number'];
    expect(
      number,
      index + 1,
      reason: 'Manifest entries must be ordered from Surah 1 to 114.',
    );

    final expectedFile =
        'surahs/${(index + 1).toString().padLeft(3, '0')}.json';
    expect(
      map['file'],
      expectedFile,
      reason: 'Surah ${index + 1} must point at $expectedFile.',
    );
    expect(
      map['sha256'],
      isA<String>(),
      reason: 'Surah ${index + 1} must have a SHA-256 string.',
    );
    expect(
      map['sha256'] as String,
      matches(RegExp(r'^[0-9a-f]{64}$')),
      reason: 'Surah ${index + 1} must have a lowercase SHA-256 digest.',
    );

    byNumber[index + 1] = map;
  }

  return byNumber;
}

Future<Map<int, String>> _actualHashesByNumber() async {
  final hashes = <int, String>{};
  for (var number = 1; number <= 114; number++) {
    final assetPath = AssetPaths.quranSurah(number);
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    expect(
      bytes,
      isNotEmpty,
      reason: 'Bundled asset $assetPath must not be empty.',
    );
    hashes[number] = sha256Hex(bytes);
  }
  return hashes;
}

String _contentChecksum(Map<int, String> hashes) {
  final buffer = StringBuffer();
  for (var number = 1; number <= 114; number++) {
    final fileName = '${number.toString().padLeft(3, '0')}.json';
    buffer
      ..write(fileName)
      ..write('\n')
      ..write(hashes[number])
      ..write('\n');
  }
  return sha256Hex(utf8.encode(buffer.toString()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SHA-256 helper matches the published FIPS 180-4 vectors', () {
    expect(
      sha256Hex(utf8.encode('')),
      'e3b0c44298fc1c149afbf4c8996fb924'
      '27ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223'
      'b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('bundles the manifest and every one of the 114 Surah files', () async {
    final manifest = await const QuranManifestDataSource().loadManifest();

    expect(manifest.surahCount, 114);
    for (var number = 1; number <= 114; number++) {
      final assetPath = AssetPaths.quranSurah(number);
      final data = await rootBundle.load(assetPath);

      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Bundled asset $assetPath must not be empty.',
      );
    }
  });

  test(
    'manifest declares a SHA-256 digest for each of the 114 Surahs',
    () async {
      final manifest = await _loadManifestJson();
      final entries = _manifestEntriesByNumber(manifest);

      expect(
        entries.keys,
        orderedEquals(List<int>.generate(114, (i) => i + 1)),
      );

      final checksum = manifest['content_checksum'];
      expect(
        checksum,
        isA<Map<String, dynamic>>(),
        reason: 'The manifest must contain a "content_checksum" object.',
      );
      final checksumMap = checksum as Map<String, dynamic>;
      expect(checksumMap['algorithm'], 'SHA-256');
      expect(checksumMap['file_count'], 114);
      expect(
        checksumMap['value'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
        reason: 'The content checksum must be a lowercase SHA-256 digest.',
      );
    },
  );

  test('every bundled Surah file matches its manifest SHA-256', () async {
    final manifest = await _loadManifestJson();
    final entries = _manifestEntriesByNumber(manifest);
    final hashes = await _actualHashesByNumber();

    for (var number = 1; number <= 114; number++) {
      final assetPath = AssetPaths.quranSurah(number);
      final expected = entries[number]!['sha256'];
      expect(
        hashes[number],
        expected,
        reason:
            'Bundled asset $assetPath does not match the manifest SHA-256. '
            'The file is missing, modified, or the manifest is stale.',
      );
    }
  });

  test('content checksum matches the canonical per-Surah algorithm', () async {
    final manifest = await _loadManifestJson();
    final hashes = await _actualHashesByNumber();
    final computed = _contentChecksum(hashes);

    final checksum = manifest['content_checksum'] as Map<String, dynamic>;
    expect(
      computed,
      checksum['value'],
      reason:
          'Recomputing the content checksum from the 114 bundled Surah files '
          'did not reproduce the manifest value.',
    );
  });

  test(
    'asset manifest lists each Qur’an file once and no raw sources',
    () async {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      final quranAssets = assets
          .where((asset) => asset.startsWith('assets/data/quran/'))
          .toList();

      expect(assets.toSet(), hasLength(assets.length));
      expect(
        assets.where(
          (asset) => asset.endsWith('.xml') || asset.endsWith('.csv'),
        ),
        isEmpty,
      );
      expect(
        quranAssets,
        hasLength(115),
        reason:
            'Expected manifest.json plus exactly 114 Surah files under '
            'assets/data/quran/. A missing or extra file changes this count.',
      );
      expect(quranAssets.toSet(), hasLength(quranAssets.length));
      expect(
        quranAssets.where(
          (asset) =>
              asset != AssetPaths.quranManifest &&
              !asset.startsWith('${AssetPaths.quranSurahsDirectory}/'),
        ),
        isEmpty,
      );
      expect(
        assets.where(
          (asset) =>
              asset.contains('tool/quran_data') ||
              asset.contains('tanzil-uthmani') ||
              asset.contains('quranenc-english'),
        ),
        isEmpty,
      );

      for (var number = 1; number <= 114; number++) {
        expect(
          quranAssets,
          contains(AssetPaths.quranSurah(number)),
          reason: 'Surah $number must be declared as a Flutter asset.',
        );
      }
    },
  );
}
