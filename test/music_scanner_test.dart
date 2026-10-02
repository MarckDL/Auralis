import 'package:flutter_test/flutter_test.dart';
import 'package:local_audio_scan/local_audio_scan.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/music_scanner.dart';

void main() {
  test('uses safe metadata fallbacks from a track', () {
    final song = Song.fromAudioTrack(
      AudioTrack(
        id: '1',
        title: '',
        artist: ' ',
        album: '',
        duration: 65000,
        filePath: '/storage/emulated/0/Music/unknown-title.flac',
        mimeType: 'audio/flac',
        size: 10,
        dateAdded: DateTime(2026),
      ),
    );

    expect(song.title, 'unknown-title');
    expect(song.artist, 'Unknown artist');
    expect(song.album, 'Unknown album');
    expect(song.format, 'flac');
    expect(song.durationLabel, '1:05');
  });

  test('filters unsupported files and sorts songs by title', () async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(
        tracks: [
          _track('Zulu', 'z.mp3'),
          _track('Not music', 'document.txt'),
          _track('Alpha', 'a.m4a'),
        ],
      ),
    );

    final result = await scanner.scan();

    expect(result.status, MusicScanStatus.success);
    expect(result.songs.map((song) => song.title), ['Alpha', 'Zulu']);
  });

  test('returns an empty status when no supported songs are found', () async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(tracks: [_track('Text', 'file.txt')]),
    );

    final result = await scanner.scan();

    expect(result.status, MusicScanStatus.empty);
    expect(result.songs, isEmpty);
  });

  test('returns permission denied when the user refuses access', () async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(permission: false, requestResult: false),
    );

    final result = await scanner.scan();

    expect(result.status, MusicScanStatus.permissionDenied);
  });
}

class FakeAudioScannerGateway implements AudioScannerGateway {
  FakeAudioScannerGateway({
    this.tracks = const [],
    this.permission = true,
    this.requestResult = true,
  });

  final List<AudioTrack> tracks;
  final bool permission;
  final bool requestResult;

  @override
  Future<bool> checkPermission() async => permission;

  @override
  Future<bool> requestPermission() async => requestResult;

  @override
  Future<List<AudioTrack>> scanTracks() async => tracks;
}

AudioTrack _track(String title, String path) {
  return AudioTrack(
    id: title,
    title: title,
    artist: 'Artist',
    album: 'Album',
    duration: 125000,
    filePath: '/storage/emulated/0/Music/$path',
    mimeType: 'audio/mpeg',
    size: 1000,
    dateAdded: DateTime(2026),
  );
}
