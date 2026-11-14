import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/quran/domain/quran_ayah.dart';
import 'package:tafseer_audio/features/quran/domain/quran_surah.dart';

const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
const _specialBasmala = 'بِسْمِ ٱللَّهِ ۞ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

QuranAyah _ayah(int number) {
  return QuranAyah(
    number: number,
    arabic: 'آية $number',
    translation: 'Ayah $number',
    footnotes: '',
    sajdah: false,
  );
}

Map<String, dynamic> _surahJson({
  Object? number = 2,
  Object? basmalaMode = 'prefatory',
  Object? basmalaText = _basmala,
  Object? ayahs,
}) {
  return <String, dynamic>{
    'surah_number': number,
    'basmala_mode': basmalaMode,
    'basmala_text': basmalaText,
    'ayahs': ayahs ?? [_ayahMap(1), _ayahMap(2)],
  };
}

Map<String, dynamic> _ayahMap(int number) {
  return <String, dynamic>{
    'number': number,
    'arabic': 'آية $number',
    'translation': 'Ayah $number',
    'footnotes': '',
    'sajdah': false,
  };
}

void main() {
  test('parses a valid Surah and preserves its Basmala text exactly', () {
    final surah = QuranSurah.fromJson(_surahJson());

    expect(surah.number, 2);
    expect(surah.basmalaMode, BasmalaMode.prefatory);
    expect(surah.basmalaText, _basmala);
    expect(surah.ayahs, hasLength(2));
    expect(surah.ayahs[0], _ayah(1));
    expect(surah.ayahs[1], _ayah(2));
  });

  test('preserves a special Basmala spelling without normalization', () {
    final surah = QuranSurah.fromJson(_surahJson(basmalaText: _specialBasmala));

    expect(surah.basmalaText, _specialBasmala);
    expect(surah.basmalaText, isNot(_basmala));
  });

  test('requires Surah 1 to use the ayah Basmala mode', () {
    final surah = QuranSurah.fromJson(
      _surahJson(number: 1, basmalaMode: 'ayah', basmalaText: null),
    );

    expect(surah.basmalaMode, BasmalaMode.ayah);
    expect(surah.basmalaText, isNull);
  });

  test('requires Surah 9 to use the none Basmala mode', () {
    final surah = QuranSurah.fromJson(
      _surahJson(number: 9, basmalaMode: 'none', basmalaText: null),
    );

    expect(surah.basmalaMode, BasmalaMode.none);
    expect(surah.basmalaText, isNull);
  });

  test('requires every other Surah to use the prefatory Basmala mode', () {
    for (final number in [2, 95, 97, 114]) {
      final surah = QuranSurah.fromJson(_surahJson(number: number));

      expect(surah.basmalaMode, BasmalaMode.prefatory);
      expect(surah.basmalaText, isNotEmpty);
    }
  });

  test('rejects a Basmala mode that contradicts the dataset rules', () {
    final invalidCases = [
      (number: 1, mode: 'prefatory', text: _basmala),
      (number: 1, mode: 'none', text: null),
      (number: 9, mode: 'prefatory', text: _basmala),
      (number: 9, mode: 'ayah', text: null),
      (number: 2, mode: 'ayah', text: null),
      (number: 2, mode: 'none', text: null),
      (number: 114, mode: 'ayah', text: null),
    ];

    for (final invalid in invalidCases) {
      expect(
        () => QuranSurah.fromJson(
          _surahJson(
            number: invalid.number,
            basmalaMode: invalid.mode,
            basmalaText: invalid.text,
          ),
        ),
        throwsA(isA<FormatException>()),
        reason: 'Surah ${invalid.number} must not use "${invalid.mode}".',
      );
    }
  });

  test('rejects unknown Basmala modes', () {
    expect(
      () => QuranSurah.fromJson(_surahJson(basmalaMode: 'unknown')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranSurah.fromJson(_surahJson(basmalaMode: null)),
      throwsA(isA<FormatException>()),
    );
  });

  test('requires non-empty Basmala text for prefatory Surahs', () {
    for (final text in [null, '', '   ', '\n\t']) {
      expect(
        () => QuranSurah.fromJson(_surahJson(basmalaText: text)),
        throwsA(isA<FormatException>()),
        reason: 'Prefatory text $text must be rejected.',
      );
    }
  });

  test('requires null Basmala text for ayah and none modes', () {
    expect(
      () => QuranSurah.fromJson(
        _surahJson(number: 1, basmalaMode: 'ayah', basmalaText: _basmala),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranSurah.fromJson(
        _surahJson(number: 9, basmalaMode: 'none', basmalaText: _basmala),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects Surah numbers outside 1 to 114', () {
    for (final number in [0, -1, 115]) {
      expect(
        () => QuranSurah.fromJson(_surahJson(number: number)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => QuranSurah(
          number: number,
          basmalaMode: BasmalaMode.prefatory,
          basmalaText: _basmala,
          ayahs: [_ayah(1)],
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('rejects a Surah without Ayahs', () {
    expect(
      () => QuranSurah.fromJson(_surahJson(ayahs: const [])),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranSurah(
        number: 2,
        basmalaMode: BasmalaMode.prefatory,
        basmalaText: _basmala,
        ayahs: const [],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects Ayah lists that are not sequential from 1', () {
    final invalidLists = [
      [_ayahMap(2)],
      [_ayahMap(1), _ayahMap(3)],
      [_ayahMap(1), _ayahMap(1)],
      [_ayahMap(2), _ayahMap(3)],
    ];

    for (final ayahs in invalidLists) {
      expect(
        () => QuranSurah.fromJson(_surahJson(ayahs: ayahs)),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('stores the Ayah list as unmodifiable', () {
    final surah = QuranSurah.fromJson(_surahJson());

    expect(() => surah.ayahs.add(_ayah(3)), throwsUnsupportedError);
    expect(() => surah.ayahs.removeAt(0), throwsUnsupportedError);
    expect(() => surah.ayahs.clear(), throwsUnsupportedError);
  });

  test('rejects missing top-level fields', () {
    for (final key in [
      'surah_number',
      'basmala_mode',
      'basmala_text',
      'ayahs',
    ]) {
      final json = _surahJson()..remove(key);

      expect(
        () => QuranSurah.fromJson(json),
        throwsA(isA<FormatException>()),
        reason: 'Missing "$key" must be rejected.',
      );
    }
  });

  test('rejects a non-list Ayah collection and non-object entries', () {
    expect(
      () => QuranSurah.fromJson(_surahJson(ayahs: 'not a list')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranSurah.fromJson(_surahJson(ayahs: [1, 2])),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects invalid Ayah entries and identifies the Surah', () {
    final invalidAyah = _ayahMap(1)..remove('translation');

    expect(
      () => QuranSurah.fromJson(_surahJson(ayahs: [invalidAyah])),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Surah 2'),
        ),
      ),
    );
  });

  test('compares values rather than object identity', () {
    final first = QuranSurah.fromJson(_surahJson());
    final second = QuranSurah.fromJson(_surahJson());

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(
      first,
      isNot(QuranSurah.fromJson(_surahJson(basmalaText: _specialBasmala))),
    );
  });
}
