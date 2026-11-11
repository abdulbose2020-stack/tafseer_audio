import 'revelation_place.dart';

/// Immutable metadata for one Surah of the Qur'an.
class Surah {
  const Surah({
    required this.number,
    required this.arabicName,
    required this.transliteration,
    required this.englishMeaning,
    required this.ayahCount,
    required this.revelationPlace,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    final number = _readInt(json, 'number');
    final ayahCount = _readInt(json, 'ayah_count');
    final arabicName = _readString(json, 'arabic_name');
    final transliteration = _readString(json, 'transliteration');
    final englishMeaning = _readString(json, 'english_meaning');

    if (number < 1 || number > 114) {
      throw FormatException(
        'Surah number must be between 1 and 114, got $number.',
      );
    }
    if (ayahCount < 1) {
      throw FormatException(
        'Surah $number must have at least one Ayah, got $ayahCount.',
      );
    }

    return Surah(
      number: number,
      arabicName: arabicName,
      transliteration: transliteration,
      englishMeaning: englishMeaning,
      ayahCount: ayahCount,
      revelationPlace: RevelationPlace.fromJson(json['revelation_place']),
    );
  }

  /// Position in the Mushaf, from 1 to 114.
  final int number;

  /// The Surah name in Arabic script.
  final String arabicName;

  /// Latin transliteration of the Arabic name.
  final String transliteration;

  /// English translation of the name.
  final String englishMeaning;

  /// Number of Ayahs in the Surah.
  final int ayahCount;

  /// Whether the Surah is Makki or Madani.
  final RevelationPlace revelationPlace;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Surah &&
            number == other.number &&
            arabicName == other.arabicName &&
            transliteration == other.transliteration &&
            englishMeaning == other.englishMeaning &&
            ayahCount == other.ayahCount &&
            revelationPlace == other.revelationPlace;
  }

  @override
  int get hashCode => Object.hash(
    number,
    arabicName,
    transliteration,
    englishMeaning,
    ayahCount,
    revelationPlace,
  );

  @override
  String toString() => 'Surah($number, $transliteration)';
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
