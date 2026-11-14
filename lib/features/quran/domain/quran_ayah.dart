/// One Ayah of the Qur'an with its exact Arabic text, translation, footnotes,
/// and Sajdah marker.
///
/// The source strings are stored exactly as published. They are never
/// trimmed, Unicode-normalized, stripped of Arabic marks, or otherwise
/// transformed.
class QuranAyah {
  const QuranAyah({
    required this.number,
    required this.arabic,
    required this.translation,
    required this.footnotes,
    required this.sajdah,
  });

  factory QuranAyah.fromJson(Map<String, dynamic> json) {
    final number = _readInt(json, 'number');
    if (number < 1) {
      throw FormatException('Ayah number must be at least 1, got $number.');
    }

    return QuranAyah(
      number: number,
      arabic: _readNonEmptyString(json, 'arabic'),
      translation: _readNonEmptyString(json, 'translation'),
      footnotes: _readString(json, 'footnotes'),
      sajdah: _readBool(json, 'sajdah'),
    );
  }

  /// Position within the Surah, starting at 1.
  final int number;

  /// The exact Arabic Qur'an text from the source.
  final String arabic;

  /// The exact English translation from the source.
  final String translation;

  /// The complete footnote text for this Ayah, or an empty string.
  final String footnotes;

  /// Whether this Ayah includes a Sajdah.
  final bool sajdah;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is QuranAyah &&
            number == other.number &&
            arabic == other.arabic &&
            translation == other.translation &&
            footnotes == other.footnotes &&
            sajdah == other.sajdah;
  }

  @override
  int get hashCode =>
      Object.hash(number, arabic, translation, footnotes, sajdah);

  @override
  String toString() => 'QuranAyah($number)';
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
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string, got $value.');
  }
  return value;
}

String _readNonEmptyString(Map<String, dynamic> json, String key) {
  final value = _readString(json, key);
  if (value.trim().isEmpty) {
    throw FormatException('Expected "$key" to be a non-empty string.');
  }
  return value;
}

bool _readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Expected "$key" to be a boolean, got $value.');
  }
  return value;
}
