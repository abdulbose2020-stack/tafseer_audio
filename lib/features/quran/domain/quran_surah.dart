import 'quran_ayah.dart';

/// How the Basmala is represented in one Surah.
enum BasmalaMode {
  /// The Basmala is Ayah 1 of the Surah.
  ayah('ayah'),

  /// The Basmala is a prefatory line before Ayah 1.
  prefatory('prefatory'),

  /// The Surah has no Basmala.
  none('none');

  const BasmalaMode(this.jsonValue);

  /// Stable value used in the bundled Qur'an JSON.
  final String jsonValue;

  static BasmalaMode fromJson(Object? value) {
    return switch (value) {
      'ayah' => BasmalaMode.ayah,
      'prefatory' => BasmalaMode.prefatory,
      'none' => BasmalaMode.none,
      _ => throw FormatException('Unknown Basmala mode: $value'),
    };
  }
}

/// The complete text of one Surah, including its Basmala metadata and Ayahs.
///
/// Surah names, translation names, revelation place, and Ayah counts remain in
/// the shared `Surah` metadata model; this class only carries revealed text.
class QuranSurah {
  QuranSurah({
    required this.number,
    required this.basmalaMode,
    required this.basmalaText,
    required List<QuranAyah> ayahs,
  }) : ayahs = List<QuranAyah>.unmodifiable(ayahs) {
    if (number < 1 || number > 114) {
      throw FormatException(
        'Surah number must be between 1 and 114, got $number.',
      );
    }

    final expectedMode = _expectedBasmalaMode(number);
    if (basmalaMode != expectedMode) {
      throw FormatException(
        'Surah $number must use Basmala mode '
        '"${expectedMode.jsonValue}", got "${basmalaMode.jsonValue}".',
      );
    }

    switch (basmalaMode) {
      case BasmalaMode.prefatory:
        if (basmalaText == null || basmalaText!.trim().isEmpty) {
          throw FormatException(
            'Surah $number must have a non-empty Basmala text.',
          );
        }
      case BasmalaMode.ayah:
      case BasmalaMode.none:
        if (basmalaText != null) {
          throw FormatException(
            'Surah $number must not have a Basmala text when its mode is '
            '"${basmalaMode.jsonValue}".',
          );
        }
    }

    if (this.ayahs.isEmpty) {
      throw FormatException('Surah $number must contain at least one Ayah.');
    }

    for (var index = 0; index < this.ayahs.length; index++) {
      final expectedNumber = index + 1;
      final actualNumber = this.ayahs[index].number;
      if (actualNumber != expectedNumber) {
        throw FormatException(
          'Surah $number Ayah numbers must be sequential from 1; expected '
          '$expectedNumber, got $actualNumber.',
        );
      }
    }
  }

  factory QuranSurah.fromJson(Map<String, dynamic> json) {
    final number = _readInt(json, 'surah_number');
    if (number < 1 || number > 114) {
      throw FormatException(
        'Surah number must be between 1 and 114, got $number.',
      );
    }

    final basmalaMode = BasmalaMode.fromJson(json['basmala_mode']);

    if (!json.containsKey('basmala_text')) {
      throw FormatException(
        'Surah $number must contain a "basmala_text" field.',
      );
    }
    final basmalaText = _readNullableString(json, 'basmala_text');

    final rawAyahs = json['ayahs'];
    if (rawAyahs is! List) {
      throw FormatException('Surah $number must contain an "ayahs" list.');
    }

    final ayahs = <QuranAyah>[];
    for (var index = 0; index < rawAyahs.length; index++) {
      final entry = rawAyahs[index];
      if (entry is! Map) {
        throw FormatException(
          'Surah $number Ayah entry $index is not a JSON object.',
        );
      }

      try {
        ayahs.add(QuranAyah.fromJson(Map<String, dynamic>.from(entry)));
      } on FormatException catch (error) {
        throw FormatException(
          'Surah $number Ayah entry $index: ${error.message}',
        );
      }
    }

    return QuranSurah(
      number: number,
      basmalaMode: basmalaMode,
      basmalaText: basmalaText,
      ayahs: ayahs,
    );
  }

  /// Position in the Mushaf, from 1 to 114.
  final int number;

  /// How the Basmala is represented for this Surah.
  final BasmalaMode basmalaMode;

  /// The exact prefatory Basmala text, or `null` when the mode is not
  /// [BasmalaMode.prefatory].
  final String? basmalaText;

  /// The unmodifiable Ayahs in Mushaf order.
  final List<QuranAyah> ayahs;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is QuranSurah &&
            number == other.number &&
            basmalaMode == other.basmalaMode &&
            basmalaText == other.basmalaText &&
            _listEquals(ayahs, other.ayahs);
  }

  @override
  int get hashCode {
    return Object.hash(number, basmalaMode, basmalaText, Object.hashAll(ayahs));
  }

  @override
  String toString() => 'QuranSurah($number, ${ayahs.length} Ayahs)';
}

BasmalaMode _expectedBasmalaMode(int number) {
  if (number == 1) {
    return BasmalaMode.ayah;
  }
  if (number == 9) {
    return BasmalaMode.none;
  }
  return BasmalaMode.prefatory;
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Expected "$key" to be an integer, got $value.');
  }
  return value;
}

String? _readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException(
      'Expected "$key" to be a string or null, got $value.',
    );
  }
  return value;
}

bool _listEquals(List<QuranAyah> first, List<QuranAyah> second) {
  if (identical(first, second)) {
    return true;
  }
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
