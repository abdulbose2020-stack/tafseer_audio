import 'package:flutter_test/flutter_test.dart';
import 'package:tafseer_audio/features/quran/domain/quran_ayah.dart';

const _arabic = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
const _translation = 'In the name of Allāh,[2] the Entirely Merciful.';
const _footnotes =
    '[2] A footnote with a newline.\n[3] A second footnote, unchanged.';

Map<String, dynamic> _json({
  Object? number = 1,
  Object? arabic = _arabic,
  Object? translation = _translation,
  Object? footnotes = _footnotes,
  Object? sajdah = false,
}) {
  return <String, dynamic>{
    'number': number,
    'arabic': arabic,
    'translation': translation,
    'footnotes': footnotes,
    'sajdah': sajdah,
  };
}

void main() {
  test('parses every field and preserves the source text exactly', () {
    final ayah = QuranAyah.fromJson(_json());

    expect(ayah.number, 1);
    expect(ayah.arabic, _arabic);
    expect(ayah.translation, _translation);
    expect(ayah.footnotes, _footnotes);
    expect(ayah.sajdah, isFalse);
    expect(ayah.footnotes, contains('\n'));
    expect(ayah.translation, contains('[2]'));
  });

  test('preserves leading and trailing whitespace in source strings', () {
    const spacedArabic = '  نص عربي  ';
    const spacedTranslation = '  A translation.  ';
    const spacedFootnotes = '  [1] A footnote.  ';

    final ayah = QuranAyah.fromJson(
      _json(
        arabic: spacedArabic,
        translation: spacedTranslation,
        footnotes: spacedFootnotes,
      ),
    );

    expect(ayah.arabic, spacedArabic);
    expect(ayah.translation, spacedTranslation);
    expect(ayah.footnotes, spacedFootnotes);
  });

  test('allows empty footnotes and parses a Sajdah marker', () {
    final ayah = QuranAyah.fromJson(_json(footnotes: '', sajdah: true));

    expect(ayah.footnotes, isEmpty);
    expect(ayah.sajdah, isTrue);
  });

  test('rejects missing fields', () {
    for (final key in [
      'number',
      'arabic',
      'translation',
      'footnotes',
      'sajdah',
    ]) {
      final json = _json()..remove(key);

      expect(
        () => QuranAyah.fromJson(json),
        throwsA(isA<FormatException>()),
        reason: 'Missing "$key" must be rejected.',
      );
    }
  });

  test('rejects empty or whitespace-only Arabic and translation', () {
    for (final key in ['arabic', 'translation']) {
      for (final value in ['', '   ', '\n\t']) {
        expect(
          () => QuranAyah.fromJson(_json()..[key] = value),
          throwsA(isA<FormatException>()),
          reason: '"$key" with value ${value.runes} must be rejected.',
        );
      }
    }
  });

  test('rejects invalid field types', () {
    expect(
      () => QuranAyah.fromJson(_json(number: '1')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranAyah.fromJson(_json(number: 1.0)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranAyah.fromJson(_json(arabic: 1)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranAyah.fromJson(_json(translation: null)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranAyah.fromJson(_json(footnotes: null)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => QuranAyah.fromJson(_json(sajdah: 'false')),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects Ayah numbers below 1', () {
    for (final number in [0, -1]) {
      expect(
        () => QuranAyah.fromJson(_json(number: number)),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('compares values rather than object identity', () {
    final first = QuranAyah.fromJson(_json());
    final second = QuranAyah.fromJson(_json());

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first, isNot(QuranAyah.fromJson(_json(number: 2))));
  });
}
