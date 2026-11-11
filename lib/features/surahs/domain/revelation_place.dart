/// Where a Surah was revealed.
enum RevelationPlace {
  makki(label: 'Makki', jsonValue: 'makki'),
  madani(label: 'Madani', jsonValue: 'madani');

  const RevelationPlace({required this.label, required this.jsonValue});

  /// Human-readable label used in the UI.
  final String label;

  /// Stable value used in the bundled JSON metadata.
  final String jsonValue;

  static RevelationPlace fromJson(Object? value) {
    return switch (value) {
      'makki' => RevelationPlace.makki,
      'madani' => RevelationPlace.madani,
      _ => throw FormatException('Unknown revelation place: $value'),
    };
  }
}
