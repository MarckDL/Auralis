import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_audio_scan/local_audio_scan.dart';

import 'package:auralis/main.dart';
import 'package:auralis/models/song.dart';
import 'package:auralis/services/audio_handler.dart';
import 'package:auralis/services/music_scanner.dart';

void main() {
  testWidgets('shows the Auralis home screen', (WidgetTester tester) async {
    await tester.pumpWidget(AuralisApp(playbackGateway: FakePlaybackGateway()));

    expect(find.text('Your sound,\nyour space.'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Midnight Signals'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('navigates between the main sections', (WidgetTester tester) async {
    await tester.pumpWidget(AuralisApp(playbackGateway: FakePlaybackGateway()));

    await tester.tap(find.text('Playlists'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Preferences'), findsOneWidget);
  });

  testWidgets('renders songs returned by the scanner', (WidgetTester tester) async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(tracks: [_track('Song A', 'a.mp3')]),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LibraryScreen(scanner: scanner))),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 songs'), findsOneWidget);
    expect(find.text('Song A'), findsOneWidget);
  });

  testWidgets('shows a permission state when access is denied',
      (WidgetTester tester) async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(permission: false, requestResult: false),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LibraryScreen(scanner: scanner))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Music permission required'), findsOneWidget);
    expect(find.text('Allow access'), findsOneWidget);
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

class FakePlaybackGateway implements PlaybackGateway {
  final _playback = StreamController<PlaybackState>.broadcast();
  final _media = StreamController<MediaItem?>.broadcast();
  final _queue = StreamController<List<MediaItem>>.broadcast();

  @override
  Stream<PlaybackState> get playbackStateStream => _playback.stream;
  @override
  Stream<MediaItem?> get mediaItemStream => _media.stream;
  @override
  Stream<List<MediaItem>> get queueStream => _queue.stream;
  @override
  Future<void> setQueue(List<Song> songs, int initialIndex) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> skipToNext() async {}
  @override
  Future<void> skipToPrevious() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {}
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {}
}
