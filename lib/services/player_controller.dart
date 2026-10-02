import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../models/song.dart';
import 'audio_handler.dart';

enum PlayerStatus { idle, loading, ready, error }

class PlayerController extends ChangeNotifier {
  PlayerController({
    required this._gateway,
    this.onSongStarted,
    this.onPositionChanged,
    this.onSeek,
    this.onPlaybackCompleted,
  }) {
    _subscriptions = [
      _gateway.playbackStateStream.listen(_onPlaybackState),
      _gateway.mediaItemStream.listen(_onMediaItem),
      _gateway.queueStream.listen((items) {
        if (items.isEmpty) return;
        notifyListeners();
      }),
    ];
  }

  final PlaybackGateway _gateway;
  final Future<void> Function(Song song)? onSongStarted;
  final Future<void> Function(Song song, Duration position, bool isPlaying)? onPositionChanged;
  final void Function(Song song, Duration position)? onSeek;
  final Future<void> Function()? onPlaybackCompleted;
  late final List<StreamSubscription<Object?>> _subscriptions;
  List<Song> _songs = const [];
  int _currentIndex = -1;
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerStatus _status = PlayerStatus.idle;
  String? _errorMessage;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  Song? get currentSong => _currentSong;
  List<Song> get currentSongs => List.unmodifiable(_songs);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayerStatus get status => _status;
  String? get errorMessage => _errorMessage;
  AudioServiceShuffleMode get shuffleMode => _shuffleMode;
  AudioServiceRepeatMode get repeatMode => _repeatMode;

  Future<void> playSong(Song song, List<Song> songs) async {
    final index = songs.indexWhere((item) => item.id == song.id);
    _songs = List.unmodifiable(songs);
    _currentIndex = index == -1 ? 0 : index;
    _currentSong = song;
    _position = Duration.zero;
    _duration = song.duration;
    _status = PlayerStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _gateway.setQueue(_songs, _currentIndex);
      await _gateway.play();
      await onSongStarted?.call(song);
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> play() async {
    if (_currentSong == null) return;
    try {
      await _gateway.play();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> pause() async {
    try {
      await _gateway.pause();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> stop() async {
    try {
      await _gateway.stop();
      _position = Duration.zero;
      if (_currentSong != null) {
        onSeek?.call(_currentSong!, Duration.zero);
      }
      notifyListeners();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> togglePlayPause() => isPlaying ? pause() : play();

  Future<void> seek(Duration position) async {
    final safePosition = position < Duration.zero
        ? Duration.zero
        : position > duration
            ? duration
            : position;
    try {
      await _gateway.seek(safePosition);
      _position = safePosition;
      if (_currentSong != null) {
        onSeek?.call(_currentSong!, safePosition);
      }
      notifyListeners();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> next() async {
    if (_songs.isEmpty) return;
    try {
      await _gateway.skipToNext();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> previous() async {
    if (_songs.isEmpty) return;
    if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    try {
      await _gateway.skipToPrevious();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    try {
      await _gateway.setShuffleMode(mode);
      _shuffleMode = mode;
      notifyListeners();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> toggleShuffle() => setShuffleMode(
        _shuffleMode == AudioServiceShuffleMode.none
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      );

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    try {
      await _gateway.setRepeatMode(mode);
      _repeatMode = mode;
      notifyListeners();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> cycleRepeatMode() {
    final nextMode = switch (_repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one || AudioServiceRepeatMode.group =>
        AudioServiceRepeatMode.none,
    };
    return setRepeatMode(nextMode);
  }

  void _onPlaybackState(PlaybackState state) {
    final previousSong = _currentSong;
    _isPlaying = state.playing;
    final rawPosition = state.updatePosition;
    if (state.queueIndex != null && state.queueIndex! < _songs.length) {
      _currentIndex = state.queueIndex!;
      _currentSong = _songs[_currentIndex];
      _duration = _currentSong!.duration;
    }
    if (previousSong?.id != _currentSong?.id && _currentSong != null) {
      _position = Duration.zero;
      onSeek?.call(_currentSong!, Duration.zero);
    } else {
      _position = rawPosition < Duration.zero
          ? Duration.zero
          : rawPosition > _duration && _duration > Duration.zero
              ? _duration
              : rawPosition;
    }
    _status = switch (state.processingState) {
      AudioProcessingState.idle => PlayerStatus.idle,
      AudioProcessingState.loading || AudioProcessingState.buffering =>
        PlayerStatus.loading,
      AudioProcessingState.ready || AudioProcessingState.completed =>
        PlayerStatus.ready,
      AudioProcessingState.error => PlayerStatus.error,
    };
    if (state.processingState == AudioProcessingState.error ||
        state.errorCode != null) {
      _errorMessage = state.errorMessage ?? 'Unable to play this song.';
    }
    final song = _currentSong;
    if (song != null) {
      onPositionChanged?.call(song, _position, _isPlaying);
    }
    if (state.processingState == AudioProcessingState.completed) {
      onPlaybackCompleted?.call();
    }
    notifyListeners();
  }

  void _onMediaItem(MediaItem? item) {
    if (item == null) return;
    final index = _songs.indexWhere((song) => song.id == item.id);
    if (index == -1) return;
    _currentIndex = index;
    _currentSong = _songs[index];
    _duration = item.duration ?? _currentSong!.duration;
    notifyListeners();
  }

  void _setError(String message) {
    _status = PlayerStatus.error;
    _errorMessage = message;
    _isPlaying = false;
    notifyListeners();
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Unable to play this song.' : message;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
