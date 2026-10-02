import 'dart:typed_data';

import 'package:local_audio_scan/local_audio_scan.dart';

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.path,
    required this.format,
    required this.mimeType,
    this.genre = 'Unknown genre',
    this.artwork,
  });

  factory Song.fromAudioTrack(AudioTrack track) {
    final fileName = _fileNameWithoutExtension(track.filePath);

    return Song(
      id: track.id,
      title: _fallback(track.title, fileName),
      artist: _fallback(track.artist, 'Unknown artist'),
      album: _fallback(track.album, 'Unknown album'),
      duration: Duration(milliseconds: track.duration),
      path: track.filePath,
      format: _extension(track.filePath),
      mimeType: track.mimeType,
      genre: 'Unknown genre',
      artwork: track.artwork,
    );
  }

  static const supportedExtensions = {
    'mp3',
    'm4a',
    'mp4',
    'flac',
    'ogg',
    'opus',
    'wav',
    'webm',
    'mkv',
    'ape',
    'aif',
    'aiff',
    'aifc',
    'mov',
  };

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String path;
  final String format;
  final String mimeType;
  final String genre;
  final Uint8List? artwork;

  bool get hasArtwork => artwork != null && artwork!.isNotEmpty;

  String get durationLabel {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _fallback(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  static String _extension(String path) {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static String _fileNameWithoutExtension(String path) {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final dot = fileName.lastIndexOf('.');
    final title = dot > 0 ? fileName.substring(0, dot) : fileName;
    return _fallback(title, 'Unknown title');
  }
}
