import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/surahs/data/surah_asset_data_source.dart';

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.json);

  final String json;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
  }
}

const _validJson = '''
{
  "source": {"name": "Tanzil Quran Metadata"},
  "surahs": [
    {
      "number": 1,
      "arabic_name": "الفاتحة",
      "transliteration": "Al-Faatiha",
      "english_meaning": "The Opening",
      "ayah_count": 7,
      "revelation_place": "makki"
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the complete bundled catalogue asset', () async {
    final surahs = await const SurahAssetDataSource().loadSurahs();

    expect(surahs, hasLength(114));
    expect(surahs.first.number, 1);
    expect(surahs.last.number, 114);
  });

  test('parses a valid JSON document', () async {
    final source = SurahAssetDataSource(
      assetPath: 'test.json',
      bundle: _StringAssetBundle(_validJson),
    );

    final surahs = await source.loadSurahs();

    expect(surahs, hasLength(1));
    expect(surahs.single.number, 1);
    expect(surahs.single.transliteration, 'Al-Faatiha');
    expect(surahs.single.arabicName, 'الفاتحة');
  });

  test('rejects a document that is not a JSON object', () async {
    final source = SurahAssetDataSource(
      assetPath: 'test.json',
      bundle: _StringAssetBundle('[]'),
    );

    expect(source.loadSurahs(), throwsA(isA<FormatException>()));
  });

  test('rejects a document without a Surah list', () async {
    final source = SurahAssetDataSource(
      assetPath: 'test.json',
      bundle: _StringAssetBundle('{"source": {}}'),
    );

    expect(source.loadSurahs(), throwsA(isA<FormatException>()));
  });

  test('rejects invalid Surah entries', () async {
    final source = SurahAssetDataSource(
      assetPath: 'test.json',
      bundle: _StringAssetBundle(
        '{"surahs": [{"number": 0, "arabic_name": "x", '
        '"transliteration": "x", "english_meaning": "x", '
        '"ayah_count": 1, "revelation_place": "makki"}]}',
      ),
    );

    expect(source.loadSurahs(), throwsA(isA<FormatException>()));
  });
}
