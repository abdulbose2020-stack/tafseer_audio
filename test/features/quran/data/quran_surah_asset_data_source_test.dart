import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/core/constants/asset_paths.dart';
import 'package:tafseer_audio/features/quran/data/asset_quran_repository.dart';
import 'package:tafseer_audio/features/quran/data/quran_surah_asset_data_source.dart';
import 'package:tafseer_audio/features/quran/domain/quran_surah.dart';

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.json);

  /// The JSON returned for every key, or `null` to simulate a missing asset.
  final String? json;
  final List<String> loadedKeys = [];

  @override
  Future<ByteData> load(String key) async {
    loadedKeys.add(key);
    final value = json;
    if (value == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
const _arabic = 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ';
const _translation = '[All] praise is [due] to Allāh, Lord[4] of the worlds -';
const _footnotes = '[4] A footnote.\n[5] A second footnote.';

Map<String, dynamic> _ayahMap(int number) {
  return <String, dynamic>{
    'number': number,
    'arabic': '$_arabic $number',
    'translation': '$_translation $number',
    'footnotes': _footnotes,
    'sajdah': number.isEven,
  };
}

Map<String, dynamic> _surahMap({
  int number = 1,
  String basmalaMode = 'ayah',
  String? basmalaText,
  List<Map<String, dynamic>>? ayahs,
}) {
  return <String, dynamic>{
    'surah_number': number,
    'basmala_mode': basmalaMode,
    'basmala_text': basmalaText,
    'ayahs': ayahs ?? [_ayahMap(1), _ayahMap(2)],
  };
}

String _surahJson({
  int number = 1,
  String basmalaMode = 'ayah',
  String? basmalaText,
  List<Map<String, dynamic>>? ayahs,
}) {
  return jsonEncode(
    _surahMap(
      number: number,
      basmalaMode: basmalaMode,
      basmalaText: basmalaText,
      ayahs: ayahs,
    ),
  );
}

Future<Map<String, dynamic>> _loadRaw(int number) async {
  final rawJson = await rootBundle.loadString(AssetPaths.quranSurah(number));
  return jsonDecode(rawJson) as Map<String, dynamic>;
}

void _expectMatchesRaw(QuranSurah surah, Map<String, dynamic> raw) {
  expect(surah.number, raw['surah_number']);
  expect(surah.basmalaMode, BasmalaMode.fromJson(raw['basmala_mode']));
  expect(surah.basmalaText, raw['basmala_text']);

  final rawAyahs = raw['ayahs'] as List<dynamic>;
  expect(surah.ayahs, hasLength(rawAyahs.length));

  for (var index = 0; index < rawAyahs.length; index++) {
    final rawAyah = rawAyahs[index] as Map<String, dynamic>;
    final ayah = surah.ayahs[index];

    expect(ayah.number, rawAyah['number'], reason: 'Ayah number $index');
    expect(ayah.arabic, rawAyah['arabic'], reason: 'Arabic for $index');
    expect(
      ayah.translation,
      rawAyah['translation'],
      reason: 'Translation for $index',
    );
    expect(
      ayah.footnotes,
      rawAyah['footnotes'],
      reason: 'Footnotes for $index',
    );
    expect(ayah.sajdah, rawAyah['sajdah'], reason: 'Sajdah for $index');
  }
}

Future<void> _expectInvalidJson(String json, {int number = 1}) async {
  final source = QuranSurahAssetDataSource(bundle: _StringAssetBundle(json));

  await expectLater(
    source.loadSurah(number),
    throwsA(
      isA<FormatException>().having(
        (error) => error.message.toString(),
        'message',
        contains('Surah $number'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('real bundled assets', () {
    test('loads Surah 1 with the Basmala as an Ayah', () async {
      final raw = await _loadRaw(1);
      final surah = await const QuranSurahAssetDataSource().loadSurah(1);

      _expectMatchesRaw(surah, raw);
      expect(surah.basmalaMode, BasmalaMode.ayah);
      expect(surah.basmalaText, isNull);
      expect(surah.ayahs, hasLength(7));
    });

    test('loads Surah 2 with a prefatory Basmala and 286 Ayahs', () async {
      final raw = await _loadRaw(2);
      final surah = await const QuranSurahAssetDataSource().loadSurah(2);

      _expectMatchesRaw(surah, raw);
      expect(surah.basmalaMode, BasmalaMode.prefatory);
      expect(surah.basmalaText, isNotEmpty);
      expect(surah.ayahs, hasLength(286));
      expect(surah.ayahs.first.arabic, isNot(surah.basmalaText));
    });

    test('loads Surah 9 with no Basmala and 129 Ayahs', () async {
      final raw = await _loadRaw(9);
      final surah = await const QuranSurahAssetDataSource().loadSurah(9);

      _expectMatchesRaw(surah, raw);
      expect(surah.basmalaMode, BasmalaMode.none);
      expect(surah.basmalaText, isNull);
      expect(surah.ayahs, hasLength(129));
    });

    test(
      'preserves the special Basmala spelling in Surahs 95 and 97',
      () async {
        final standardRaw = await _loadRaw(2);
        final raw95 = await _loadRaw(95);
        final raw97 = await _loadRaw(97);
        final surah95 = await const QuranSurahAssetDataSource().loadSurah(95);
        final surah97 = await const QuranSurahAssetDataSource().loadSurah(97);

        _expectMatchesRaw(surah95, raw95);
        _expectMatchesRaw(surah97, raw97);
        expect(surah95.basmalaText, raw95['basmala_text']);
        expect(surah97.basmalaText, raw97['basmala_text']);
        expect(surah95.basmalaText, isNot(standardRaw['basmala_text']));
        expect(surah97.basmalaText, isNot(standardRaw['basmala_text']));
      },
    );

    test('loads Surah 114 with a prefatory Basmala and 6 Ayahs', () async {
      final raw = await _loadRaw(114);
      final surah = await const QuranSurahAssetDataSource().loadSurah(114);

      _expectMatchesRaw(surah, raw);
      expect(surah.basmalaMode, BasmalaMode.prefatory);
      expect(surah.basmalaText, isNotEmpty);
      expect(surah.ayahs, hasLength(6));
    });
  });

  group('validation errors', () {
    test('rejects invalid Surah numbers before loading an asset', () async {
      final bundle = _StringAssetBundle(_surahJson());
      final source = QuranSurahAssetDataSource(bundle: bundle);

      await expectLater(source.loadSurah(0), throwsRangeError);
      await expectLater(source.loadSurah(-1), throwsRangeError);
      await expectLater(source.loadSurah(115), throwsRangeError);

      expect(bundle.loadedKeys, isEmpty);
    });

    test('rejects malformed JSON and identifies the Surah', () async {
      await _expectInvalidJson('{');
      await _expectInvalidJson('');
    });

    test('rejects a document that is not a JSON object', () async {
      await _expectInvalidJson('[]');
      await _expectInvalidJson('"text"');
    });

    test('rejects missing top-level fields', () async {
      for (final key in [
        'surah_number',
        'basmala_mode',
        'basmala_text',
        'ayahs',
      ]) {
        final json = _surahMap()..remove(key);

        await _expectInvalidJson(jsonEncode(json));
      }
    });

    test('rejects an Ayah entry with a missing field', () async {
      final invalidAyah = _ayahMap(1)..remove('translation');
      final json = _surahMap(ayahs: [invalidAyah]);

      await _expectInvalidJson(jsonEncode(json));
    });

    test('rejects a Basmala mode that contradicts the Surah number', () async {
      await _expectInvalidJson(
        _surahJson(number: 2, basmalaMode: 'ayah', basmalaText: null),
        number: 2,
      );
      await _expectInvalidJson(
        _surahJson(number: 1, basmalaMode: 'prefatory', basmalaText: _basmala),
      );
    });

    test('rejects an unknown Basmala mode', () async {
      await _expectInvalidJson(_surahJson(basmalaMode: 'unknown'));
    });

    test('rejects an empty Ayah list', () async {
      await _expectInvalidJson(_surahJson(ayahs: const []));
    });

    test('rejects non-sequential Ayah numbers', () async {
      await _expectInvalidJson(_surahJson(ayahs: [_ayahMap(1), _ayahMap(3)]));
      await _expectInvalidJson(_surahJson(ayahs: [_ayahMap(2)]));
    });

    test('rejects a Surah whose number does not match the request', () async {
      await _expectInvalidJson(
        _surahJson(number: 2, basmalaMode: 'prefatory', basmalaText: _basmala),
        number: 1,
      );
    });

    test('propagates a missing asset error without a fallback', () async {
      final source = QuranSurahAssetDataSource(
        bundle: _StringAssetBundle(null),
      );

      await expectLater(source.loadSurah(1), throwsA(isA<FlutterError>()));
    });
  });

  test('repository delegates to the asset data source', () async {
    final source = QuranSurahAssetDataSource(
      bundle: _StringAssetBundle(_surahJson()),
    );
    final repository = AssetQuranRepository(source);

    final surah = await repository.loadSurah(1);

    expect(surah.number, 1);
    expect(surah.ayahs, hasLength(2));
  });
}
