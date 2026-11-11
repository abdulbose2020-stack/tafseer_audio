import 'package:flutter/foundation.dart';

/// A single playable recording in the offline audio library.
///
/// A track is deliberately independent of the Surah catalogue. The temporary
/// engine-test sample has no [surahNumber] and must never be presented as a
/// Surah tafsir recording.
@immutable
class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.title,
    required this.assetPath,
    this.subtitle,
    this.album,
    this.artist,
    this.duration,
    this.surahNumber,
    this.isTemporarySample = false,
  });

  /// Stable identifier used by the audio service and media notification.
  final String id;

  /// Human-readable title shown by the app and the media notification.
  final String title;

  /// Optional secondary line for the media notification and player UI.
  final String? subtitle;

  /// Bundled asset path. Phase 3 supports local assets only.
  final String assetPath;

  final String? album;
  final String? artist;

  /// Duration when it is already known. The player fills this in after load.
  final Duration? duration;

  /// The Surah this recording belongs to, or `null` for the engine sample.
  final int? surahNumber;

  /// Whether this is the temporary wedding-sermon engine test recording.
  final bool isTemporarySample;

  bool get isSurahRecording => surahNumber != null;

  AudioTrack copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? assetPath,
    String? album,
    String? artist,
    Duration? duration,
    int? surahNumber,
    bool? isTemporarySample,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      assetPath: assetPath ?? this.assetPath,
      album: album ?? this.album,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      surahNumber: surahNumber ?? this.surahNumber,
      isTemporarySample: isTemporarySample ?? this.isTemporarySample,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AudioTrack &&
            other.id == id &&
            other.title == title &&
            other.subtitle == subtitle &&
            other.assetPath == assetPath &&
            other.album == album &&
            other.artist == artist &&
            other.duration == duration &&
            other.surahNumber == surahNumber &&
            other.isTemporarySample == isTemporarySample;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    subtitle,
    assetPath,
    album,
    artist,
    duration,
    surahNumber,
    isTemporarySample,
  );

  @override
  String toString() => 'AudioTrack(id: $id, title: $title)';
}
