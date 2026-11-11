import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/surahs/domain/revelation_place.dart';
import 'package:tafseer_audio/features/surahs/domain/surah.dart';

void main() {
  late Map<String, dynamic> document;
  late List<Surah> surahs;

  setUpAll(() async {
    final rawJson = await File('assets/data/surahs.json').readAsString();
    document = jsonDecode(rawJson) as Map<String, dynamic>;
    final rawSurahs = document['surahs'] as List<dynamic>;
    surahs = rawSurahs
        .map((entry) => Surah.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  });

  test('contains exactly 114 Surahs in Mushaf order', () {
    expect(surahs, hasLength(114));
    expect(
      surahs.map((surah) => surah.number),
      orderedEquals(List.generate(114, (index) => index + 1)),
    );
  });

  test('Surah numbers are unique', () {
    expect(surahs.map((surah) => surah.number).toSet(), hasLength(114));
  });

  test('total Ayah count is 6,236', () {
    expect(
      surahs.fold<int>(0, (total, surah) => total + surah.ayahCount),
      6236,
    );
  });

  test('contains 86 Makki and 28 Madani Surahs', () {
    expect(
      surahs.where((surah) => surah.revelationPlace == RevelationPlace.makki),
      hasLength(86),
    );
    expect(
      surahs.where((surah) => surah.revelationPlace == RevelationPlace.madani),
      hasLength(28),
    );
  });

  test('known Surahs have the expected metadata', () {
    expect(
      surahs[0],
      const Surah(
        number: 1,
        arabicName: 'الفاتحة',
        transliteration: 'Al-Faatiha',
        englishMeaning: 'The Opening',
        ayahCount: 7,
        revelationPlace: RevelationPlace.makki,
      ),
    );
    expect(
      surahs[1],
      const Surah(
        number: 2,
        arabicName: 'البقرة',
        transliteration: 'Al-Baqara',
        englishMeaning: 'The Cow',
        ayahCount: 286,
        revelationPlace: RevelationPlace.madani,
      ),
    );
    expect(
      surahs[35],
      const Surah(
        number: 36,
        arabicName: 'يس',
        transliteration: 'Yaseen',
        englishMeaning: 'Yaseen',
        ayahCount: 83,
        revelationPlace: RevelationPlace.makki,
      ),
    );
    expect(
      surahs[54],
      const Surah(
        number: 55,
        arabicName: 'الرحمن',
        transliteration: 'Ar-Rahmaan',
        englishMeaning: 'The Beneficent',
        ayahCount: 78,
        revelationPlace: RevelationPlace.madani,
      ),
    );
    expect(
      surahs[109],
      const Surah(
        number: 110,
        arabicName: 'النصر',
        transliteration: 'An-Nasr',
        englishMeaning: 'Divine Support',
        ayahCount: 3,
        revelationPlace: RevelationPlace.madani,
      ),
    );
    expect(
      surahs[113],
      const Surah(
        number: 114,
        arabicName: 'الناس',
        transliteration: 'An-Naas',
        englishMeaning: 'Mankind',
        ayahCount: 6,
        revelationPlace: RevelationPlace.makki,
      ),
    );
  });

  test('every entry has complete metadata', () {
    for (final surah in surahs) {
      expect(
        surah.arabicName.trim(),
        isNotEmpty,
        reason: 'Surah ${surah.number} has no Arabic name.',
      );
      expect(
        surah.transliteration.trim(),
        isNotEmpty,
        reason: 'Surah ${surah.number} has no transliteration.',
      );
      expect(
        surah.englishMeaning.trim(),
        isNotEmpty,
        reason: 'Surah ${surah.number} has no English meaning.',
      );
      expect(
        surah.ayahCount,
        greaterThan(0),
        reason: 'Surah ${surah.number} has an invalid Ayah count.',
      );
    }
  });

  test('records a trustworthy metadata source', () {
    final source = document['source'] as Map<String, dynamic>;

    expect(source['name'], 'Tanzil Quran Metadata');
    expect(source['license'], 'CC BY');
    expect(source['url'], contains('tanzil.net'));
    expect(source['copyright'], contains('Tanzil.info'));
    expect(source['cross_checked_with'], contains('Quran.com'));
  });
}
