import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/audio_handler.dart';
import 'package:auralis/services/player_controller.dart';
import 'package:auralis/services/sleep_timer_controller.dart';

void main() {
  late _TimerGateway gateway;
  late PlayerController player;
  late SleepTimerController timer;

  setUp(() async {
    gateway = _TimerGateway();
    player = PlayerController(gateway: gateway);
    await player.playSong(song, [song]);
    timer = SleepTimerController(playerController: player);
  });

  tearDown(() {
    timer.dispose();
    player.dispose();
  });

  test('supports each duration option and cancellation', () {
    for (final duration in const [
      Duration(minutes: 15),
      Duration(minutes: 30),
      Duration(minutes: 45),
      Duration(minutes: 60),
    ]) {
      expect(timer.start(duration), isTrue);
      expect(timer.remaining, duration);
      timer.cancel();
      expect(timer.isActive, isFalse);
    }
  });

  test('stops playback when a short timer expires', () async {
    expect(timer.start(const Duration(seconds: 1)), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(gateway.stopCalls, 1);
    expect(timer.isActive, isFalse);
  });

  test('stops at the end of the current song', () {
    expect(timer.startAtEndOfSong(), isTrue);
    timer.handleSongCompleted();

    expect(gateway.stopCalls, 1);
    expect(timer.isActive, isFalse);
  });

  test('does not start without an active song', () {
    final emptyPlayer = PlayerController(gateway: _TimerGateway());
    final emptyTimer = SleepTimerController(playerController: emptyPlayer);

    expect(emptyTimer.start(const Duration(minutes: 15)), isFalse);
    expect(emptyTimer.errorMessage, contains('Start a song'));

    emptyTimer.dispose();
    emptyPlayer.dispose();
  });
}

const song = Song(
  id: 'timer-song', title: 'Timer Song', artist: 'Artist', album: 'Album',
  duration: Duration(minutes: 3), path: '/music/timer.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);

class _TimerGateway implements PlaybackGateway {
  final _playback = StreamController<PlaybackState>.broadcast();
  final _media = StreamController<MediaItem?>.broadcast();
  final _queue = StreamController<List<MediaItem>>.broadcast();
  int stopCalls = 0;

  @override Stream<PlaybackState> get playbackStateStream => _playback.stream;
  @override Stream<MediaItem?> get mediaItemStream => _media.stream;
  @override Stream<List<MediaItem>> get queueStream => _queue.stream;
  @override Future<void> setQueue(List<Song> songs, int index) async {}
  @override Future<void> play() async {}
  @override Future<void> pause() async {}
  @override Future<void> seek(Duration position) async {}
  @override Future<void> skipToNext() async {}
  @override Future<void> skipToPrevious() async {}
  @override Future<void> stop() async => stopCalls++;
  @override Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {}
  @override Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {}
}
