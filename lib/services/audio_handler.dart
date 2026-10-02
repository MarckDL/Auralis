import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

abstract interface class PlaybackGateway {
  Stream<PlaybackState> get playbackStateStream;

  Stream<MediaItem?> get mediaItemStream;

  Stream<List<MediaItem>> get queueStream;

  Future<void> setQueue(List<Song> songs, int initialIndex);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> skipToNext();

  Future<void> skipToPrevious();

  Future<void> stop();

  Future<void> setShuffleMode(AudioServiceShuffleMode mode);

  Future<void> setRepeatMode(AudioServiceRepeatMode mode);
}

class AuralisAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements PlaybackGateway {
  AuralisAudioHandler({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _subscriptions = [
      _player.playbackEventStream.listen(_broadcastState),
      _player.positionStream.listen(_broadcastPosition),
      _player.currentIndexStream.listen(_updateCurrentMediaItem),
    ];
  }

  final AudioPlayer _player;
  late final List<StreamSubscription<Object?>> _subscriptions;
  List<Song> _songs = const [];
  bool _isDisposed = false;
  bool _autoAdvancePending = false;

  @override
  Stream<PlaybackState> get playbackStateStream => playbackState;

  @override
  Stream<MediaItem?> get mediaItemStream => mediaItem;

  @override
  Stream<List<MediaItem>> get queueStream => queue;

  @override
  Future<void> setQueue(List<Song> songs, int initialIndex) async {
    _songs = List.unmodifiable(songs);
    if (_songs.isEmpty) {
      await _player.stop();
      queue.add(const []);
      mediaItem.add(null);
      return;
    }

    final safeIndex = initialIndex.clamp(0, _songs.length - 1);
    final items = await Future.wait(_songs.map(_toMediaItem));
    final sources = List<AudioSource>.generate(
      _songs.length,
      (index) => AudioSource.uri(
        Uri.file(_songs[index].path),
        tag: items[index],
      ),
    );

    queue.add(items);
    await _player.setAudioSources(
      sources,
      initialIndex: safeIndex,
      initialPosition: Duration.zero,
      preload: true,
    );
    mediaItem.add(items[safeIndex]);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _player.setShuffleModeEnabled(shuffleMode == AudioServiceShuffleMode.all);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off,
    };
    await _player.setLoopMode(loopMode);
  }

  @override
  Future<void> onTaskRemoved() async {
    await super.onTaskRemoved();
  }

  void _broadcastState(PlaybackEvent event) {
    if (_player.processingState == ProcessingState.completed &&
        _player.loopMode == LoopMode.off &&
        !_autoAdvancePending) {
      _autoAdvancePending = true;
      unawaited(_advanceAfterCompletion());
    }
    final state = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
    final isPlaying = _player.playing;
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      isPlaying ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: state,
        playing: isPlaying,
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  void _broadcastPosition(Duration position) {
    if (_isDisposed || playbackState.value.processingState == AudioProcessingState.idle) {
      return;
    }
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  Future<void> _advanceAfterCompletion() async {
    try {
      if (_player.hasNext) await _player.seekToNext();
    } finally {
      _autoAdvancePending = false;
    }
  }

  void _updateCurrentMediaItem(int? index) {
    if (index == null || index < 0 || index >= queue.value.length) return;
    mediaItem.add(queue.value[index]);
  }

  Future<MediaItem> _toMediaItem(Song song) async {
    final artUri = await _writeArtwork(song);
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: artUri,
      extras: {'path': song.path, 'format': song.format},
    );
  }

  Future<Uri?> _writeArtwork(Song song) async {
    if (!song.hasArtwork) return null;
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/auralis_art_${song.id.hashCode}.jpg');
      if (!await file.exists()) await file.writeAsBytes(song.artwork!);
      return file.uri;
    } catch (_) {
      return null;
    }
  }

  Future<void> disposeHandler() async {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
  }
}
