import 'package:local_audio_scan/local_audio_scan.dart';

import '../models/song.dart';

enum MusicScanStatus { success, empty, permissionDenied, error }

class MusicScanResult {
  const MusicScanResult._({
    required this.status,
    this.songs = const [],
    this.message,
  });

  const MusicScanResult.success(List<Song> songs)
      : this._(status: MusicScanStatus.success, songs: songs);

  const MusicScanResult.empty()
      : this._(status: MusicScanStatus.empty);

  const MusicScanResult.permissionDenied()
      : this._(status: MusicScanStatus.permissionDenied);

  const MusicScanResult.error(String message)
      : this._(status: MusicScanStatus.error, message: message);

  final MusicScanStatus status;
  final List<Song> songs;
  final String? message;
}

abstract interface class AudioScannerGateway {
  Future<bool> checkPermission();

  Future<bool> requestPermission();

  Future<List<AudioTrack>> scanTracks();
}

class LocalAudioScannerGateway implements AudioScannerGateway {
  LocalAudioScannerGateway({LocalAudioScanner? scanner})
      : _scanner = scanner ?? LocalAudioScanner();

  final LocalAudioScanner _scanner;

  @override
  Future<bool> checkPermission() => _scanner.checkPermission();

  @override
  Future<bool> requestPermission() => _scanner.requestPermission();

  @override
  Future<List<AudioTrack>> scanTracks() {
    return _scanner.scanTracks(includeArtwork: true, filterJunkAudio: true);
  }
}

class MusicScanner {
  MusicScanner({AudioScannerGateway? gateway})
      : _gateway = gateway ?? LocalAudioScannerGateway();

  final AudioScannerGateway _gateway;

  Future<MusicScanResult> scan() async {
    try {
      var permissionGranted = await _gateway.checkPermission();
      if (!permissionGranted) {
        permissionGranted = await _gateway.requestPermission();
      }

      if (!permissionGranted) {
        return const MusicScanResult.permissionDenied();
      }

      final songs = (await _gateway.scanTracks())
          .where(_isSupportedTrack)
          .map(Song.fromAudioTrack)
          .toList()
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      return songs.isEmpty
          ? const MusicScanResult.empty()
          : MusicScanResult.success(songs);
    } catch (_) {
      return const MusicScanResult.error(
        'We could not scan the music on this device.',
      );
    }
  }

  bool _isSupportedTrack(AudioTrack track) {
    final path = track.filePath.toLowerCase();
    final extension = path.contains('.') ? path.split('.').last : '';
    return Song.supportedExtensions.contains(extension);
  }
}
