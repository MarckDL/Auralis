import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/audio_handler.dart';
import 'package:auralis/services/player_controller.dart';

void main() {
  late FakePlaybackGateway gateway;
  late PlayerController controller;

  setUp(() {
    gateway = FakePlaybackGateway();
    controller = PlayerController(gateway: gateway);
  });

  tearDown(() => controller.dispose());

  test('builds a queue and plays the selected song', () async {
    await controller.playSong(songA, [songA, songB]);
    await _flushStreams();

    expect(gateway.queue, [songA, songB]);
    expect(gateway.initialIndex, 0);
    expect(controller.currentSong, songA);
    expect(controller.status, PlayerStatus.ready);
    expect(controller.isPlaying, isTrue);
  });

  test('pauses, resumes and seeks', () async {
    await controller.playSong(songA, [songA, songB]);
    await controller.pause();
    await controller.play();
    await controller.seek(const Duration(seconds: 12));

    expect(controller.isPlaying, isTrue);
    expect(controller.position, const Duration(seconds: 12));
    expect(gateway.lastSeek, const Duration(seconds: 12));
  });

  test('next and previous navigate the queue', () async {
    await controller.playSong(songA, [songA, songB]);
    await controller.next();
    await _flushStreams();
    expect(controller.currentSong, songB);

    await controller.previous();
    await _flushStreams();
    expect(controller.currentSong, songA);
  });

  test('previous after three seconds seeks to the beginning', () async {
    await controller.playSong(songA, [songA, songB]);
    await controller.seek(const Duration(seconds: 18));
    await controller.previous();

    expect(controller.currentSong, songA);
    expect(gateway.lastSeek, Duration.zero);
  });

  test('shuffle and repeat are forwarded to the handler', () async {
    await controller.setShuffleMode(AudioServiceShuffleMode.all);
    await controller.setRepeatMode(AudioServiceRepeatMode.one);

    expect(controller.shuffleMode, AudioServiceShuffleMode.all);
    expect(controller.repeatMode, AudioServiceRepeatMode.one);
    expect(gateway.shuffleMode, AudioServiceShuffleMode.all);
    expect(gateway.repeatMode, AudioServiceRepeatMode.one);
  });

  test('reports a playback error', () async {
    await controller.playSong(songA, [songA]);
    gateway.emitError('File cannot be played');
    await _flushStreams();

    expect(controller.status, PlayerStatus.error);
    expect(controller.errorMessage, 'File cannot be played');
    expect(controller.isPlaying, isFalse);
  });
}

const songA = Song(
  id: 'a', title: 'Song A', artist: 'Artist', album: 'Album',
  duration: Duration(minutes: 3), path: '/music/a.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);
const songB = Song(
  id: 'b', title: 'Song B', artist: 'Artist', album: 'Album',
  duration: Duration(minutes: 4), path: '/music/b.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);

Future<void> _flushStreams() => Future<void>.delayed(Duration.zero);

class FakePlaybackGateway implements PlaybackGateway {
  final _playback = StreamController<PlaybackState>.broadcast();
  final _media = StreamController<MediaItem?>.broadcast();
  final _queueStream = StreamController<List<MediaItem>>.broadcast();
  List<Song> queue = const [];
  int initialIndex = -1;
  int currentIndex = -1;
  bool playing = false;
  Duration position = Duration.zero;
  Duration? lastSeek;
  AudioServiceShuffleMode shuffleMode = AudioServiceShuffleMode.none;
  AudioServiceRepeatMode repeatMode = AudioServiceRepeatMode.none;

  @override Stream<PlaybackState> get playbackStateStream => _playback.stream;
  @override Stream<MediaItem?> get mediaItemStream => _media.stream;
  @override Stream<List<MediaItem>> get queueStream => _queueStream.stream;

  @override
  Future<void> setQueue(List<Song> songs, int index) async {
    queue = List.of(songs);
    initialIndex = index;
    currentIndex = index;
    _queueStream.add(songs.map(_item).toList());
    _media.add(_item(songs[index]));
    _emit(AudioProcessingState.ready);
  }

  @override
  Future<void> play() async { playing = true; _emit(AudioProcessingState.ready); }
  @override
  Future<void> pause() async { playing = false; _emit(AudioProcessingState.ready); }
  @override
  Future<void> seek(Duration value) async { position = value; lastSeek = value; _emit(AudioProcessingState.ready); }
  @override
  Future<void> skipToNext() async {
    if (currentIndex < queue.length - 1) currentIndex++;
    _media.add(_item(queue[currentIndex]));
    _emit(AudioProcessingState.ready);
  }
  @override
  Future<void> skipToPrevious() async {
    if (currentIndex > 0) currentIndex--;
    _media.add(_item(queue[currentIndex]));
    _emit(AudioProcessingState.ready);
  }
  @override Future<void> stop() async { playing = false; _emit(AudioProcessingState.idle); }
  @override Future<void> setShuffleMode(AudioServiceShuffleMode value) async => shuffleMode = value;
  @override Future<void> setRepeatMode(AudioServiceRepeatMode value) async => repeatMode = value;

  void emitError(String message) => _playback.add(
        PlaybackState(processingState: AudioProcessingState.error, errorMessage: message),
      );

  void _emit(AudioProcessingState state) => _playback.add(
        PlaybackState(
          processingState: state, playing: playing, updatePosition: position,
          queueIndex: currentIndex,
        ),
      );

  MediaItem _item(Song song) => MediaItem(id: song.id, title: song.title, duration: song.duration);
}
