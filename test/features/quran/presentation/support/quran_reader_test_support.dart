import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tafseer_audio/features/quran/data/quran_surah_data_source.dart';
import 'package:tafseer_audio/features/quran/domain/quran_ayah.dart';
import 'package:tafseer_audio/features/quran/domain/quran_surah.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';

const testBasmalaText = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

const testComplexAyahText =
    'ذَٰلِكَ ٱلْكِتَٰبُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ';

const testHiddenTranslation = 'Test translation that must stay hidden';
const testHiddenFootnotes = 'Test footnote that must stay hidden';

const testSurah1 = Surah(
  number: 1,
  arabicName: 'الفاتحة',
  transliteration: 'Al-Faatiha',
  englishMeaning: 'The Opening',
  ayahCount: 7,
  revelationPlace: RevelationPlace.makki,
);

const testSurah2 = Surah(
  number: 2,
  arabicName: 'البقرة',
  transliteration: 'Al-Baqara',
  englishMeaning: 'The Cow',
  ayahCount: 286,
  revelationPlace: RevelationPlace.madani,
);

const testSurah9 = Surah(
  number: 9,
  arabicName: 'التوبة',
  transliteration: 'At-Tawbah',
  englishMeaning: 'The Repentance',
  ayahCount: 129,
  revelationPlace: RevelationPlace.madani,
);

const testSurah112 = Surah(
  number: 112,
  arabicName: 'الإخلاص',
  transliteration: 'Al-Ikhlaas',
  englishMeaning: 'Sincerity',
  ayahCount: 4,
  revelationPlace: RevelationPlace.makki,
);

const testSurahMetadata = [testSurah1, testSurah2, testSurah9, testSurah112];

QuranSurah testQuranSurah1() {
  return QuranSurah(
    number: 1,
    basmalaMode: BasmalaMode.ayah,
    basmalaText: null,
    ayahs: [
      const QuranAyah(
        number: 1,
        arabic: testBasmalaText,
        translation: 'The Opening, Ayah 1',
        footnotes: '',
        sajdah: false,
      ),
      const QuranAyah(
        number: 2,
        arabic: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
        translation: 'The Opening, Ayah 2',
        footnotes: '',
        sajdah: false,
      ),
    ],
  );
}

QuranSurah testQuranSurah2() {
  return QuranSurah(
    number: 2,
    basmalaMode: BasmalaMode.prefatory,
    basmalaText: testBasmalaText,
    ayahs: [
      const QuranAyah(
        number: 1,
        arabic: 'الٓمٓ',
        translation: testHiddenTranslation,
        footnotes: testHiddenFootnotes,
        sajdah: false,
      ),
      const QuranAyah(
        number: 2,
        arabic: testComplexAyahText,
        translation: testHiddenTranslation,
        footnotes: testHiddenFootnotes,
        sajdah: true,
      ),
    ],
  );
}

QuranSurah testQuranSurah9() {
  return QuranSurah(
    number: 9,
    basmalaMode: BasmalaMode.none,
    basmalaText: null,
    ayahs: [
      const QuranAyah(
        number: 1,
        arabic: 'بَرَآءَةٌ مِّنَ ٱللَّهِ وَرَسُولِهِ',
        translation: 'The Repentance, Ayah 1',
        footnotes: '',
        sajdah: false,
      ),
      const QuranAyah(
        number: 2,
        arabic: 'فَسِيحُوا۟ فِى ٱلْأَرْضِ أَرْبَعَةَ أَشْهُرٍ',
        translation: 'The Repentance, Ayah 2',
        footnotes: '',
        sajdah: false,
      ),
    ],
  );
}

Map<int, QuranSurah> testQuranContents() {
  return {1: testQuranSurah1(), 2: testQuranSurah2(), 9: testQuranSurah9()};
}

List<Surah> buildCatalogueSurahs() {
  return List<Surah>.generate(114, (index) {
    final number = index + 1;
    return switch (number) {
      1 => testSurah1,
      2 => testSurah2,
      9 => testSurah9,
      112 => testSurah112,
      114 => const Surah(
        number: 114,
        arabicName: 'الناس',
        transliteration: 'An-Naas',
        englishMeaning: 'Mankind',
        ayahCount: 6,
        revelationPlace: RevelationPlace.makki,
      ),
      _ => Surah(
        number: number,
        arabicName: 'سورة $number',
        transliteration: 'Surah $number',
        englishMeaning: 'Meaning $number',
        ayahCount: 3,
        revelationPlace: RevelationPlace.makki,
      ),
    };
  });
}

String quranSurahJsonFor(QuranSurah surah) {
  return jsonEncode(<String, dynamic>{
    'surah_number': surah.number,
    'basmala_mode': surah.basmalaMode.jsonValue,
    'basmala_text': surah.basmalaText,
    'ayahs': [
      for (final ayah in surah.ayahs)
        <String, dynamic>{
          'number': ayah.number,
          'arabic': ayah.arabic,
          'translation': ayah.translation,
          'footnotes': ayah.footnotes,
          'sajdah': ayah.sajdah,
        },
    ],
  });
}

/// A Qur'an data source with optional failure and loading gates.
class FakeQuranSurahDataSource implements QuranSurahDataSource {
  FakeQuranSurahDataSource(
    this.surahs, {
    this.failuresBeforeSuccess = 0,
    this.loadingCompleter,
  });

  final Map<int, QuranSurah> surahs;
  int failuresBeforeSuccess;
  final Completer<void>? loadingCompleter;
  final List<int> requestedNumbers = [];

  @override
  Future<QuranSurah> loadSurah(int number) async {
    requestedNumbers.add(number);

    final gate = loadingCompleter;
    if (gate != null) {
      await gate.future;
    }

    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw StateError('Test failure for Surah $number');
    }

    final surah = surahs[number];
    if (surah == null) {
      throw StateError('No test Qur’an content for Surah $number');
    }
    return surah;
  }
}

/// Records every asset request so tests can prove only one Surah was loaded.
class RecordingAssetBundle extends CachingAssetBundle {
  RecordingAssetBundle(this.assets);

  final Map<String, String> assets;
  final List<String> loadedKeys = [];

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loadedKeys.add(key);
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
