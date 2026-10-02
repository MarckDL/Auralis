import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/audio_player_service.dart';
import 'package:auralis/services/player_controller.dart';

void main() {
  late FakeAudioEngine engine;
  late PlayerController controller;

  setUp(() {
    engine = FakeAudioEngine();
    controller = PlayerController(engine: engine);
  });

  tearDown(() {
    controller.dispose();
  });

  test('plays the selected song and exposes its state', () async {
    await controller.playSong(songA, [songA, songB]);
    await _flushStreams();

    expect(controller.currentSong, songA);
    expect(controller.status, PlayerStatus.ready);
    expect(controller.isPlaying, isTrue);
  });

  test('pauses, resumes and seeks', () async {
    await controller.playSong(songA, [songA, songB]);
    await controller.pause();
    await controller.play();
    await controller.seek(const Duration(seconds: 12));
    await _flushStreams();

    expect(controller.isPlaying, isTrue);
    expect(controller.position, const Duration(seconds: 12));
    expect(engine.lastSeek, const Duration(seconds: 12));
  });

  test('moves to next and previous songs', () async {
    await controller.playSong(songA, [songA, songB]);
    await controller.next();
    expect(controller.currentSong, songB);

    await controller.previous();
    expect(controller.currentSong, songA);
  });

  test('previous at the beginning seeks to zero', () async {
    await controller.playSong(songA, [songA, songB]);
    await controller.seek(const Duration(seconds: 18));
    await controller.previous();

    expect(controller.currentSong, songA);
    expect(engine.lastSeek, Duration.zero);
  });

  test('reports an engine error', () async {
    await controller.playSong(songA, [songA]);
    engine.emitError('File cannot be played');
    await _flushStreams();

    expect(controller.status, PlayerStatus.error);
    expect(controller.errorMessage, 'File cannot be played');
    expect(controller.isPlaying, isFalse);
  });

}

const songA = Song(
  id: 'a',
  title: 'Song A',
  artist: 'Artist',
  album: 'Album',
  duration: Duration(minutes: 3),
  path: '/music/a.mp3',
  format: 'mp3',
  mimeType: 'audio/mpeg',
);

const songB = Song(
  id: 'b',
  title: 'Song B',
  artist: 'Artist',
  album: 'Album',
  duration: Duration(minutes: 4),
  path: '/music/b.mp3',
  format: 'mp3',
  mimeType: 'audio/mpeg',
);

Future<void> _flushStreams() => Future<void>.delayed(Duration.zero);

class FakeAudioEngine implements AudioEngine {
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _errors = StreamController<AudioEngineError>.broadcast();
  Duration? loadedDuration;
  Duration? lastSeek;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration?> get durationStream => _duration.stream;

  @override
  Stream<AudioEngineError> get errorStream => _errors.stream;

  @override
  Future<Duration?> setFilePath(String path) async {
    loadedDuration = const Duration(minutes: 3);
    _duration.add(loadedDuration);
    return loadedDuration;
  }

  @override
  Future<void> play() async => _playing.add(true);

  @override
  Future<void> pause() async => _playing.add(false);

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _position.add(position);
  }

  @override
  Future<void> stop() async => _playing.add(false);

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _position.close();
    await _duration.close();
    await _errors.close();
  }

  void emitError(String message) => _errors.add(AudioEngineError(message));
}
