import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import 'audio_player_service.dart';

enum PlayerStatus { idle, loading, ready, error }

class PlayerController extends ChangeNotifier {
  PlayerController({AudioEngine? engine})
      : _engine = engine ?? JustAudioEngine() {
    _subscriptions = [
      _engine.playingStream.listen((playing) {
        _isPlaying = playing;
        notifyListeners();
      }),
      _engine.positionStream.listen((position) {
        _position = position;
        notifyListeners();
      }),
      _engine.durationStream.listen((duration) {
        if (duration != null) _duration = duration;
        notifyListeners();
      }),
      _engine.errorStream.listen((error) {
        _setError(error.message);
      }),
    ];
  }

  final AudioEngine _engine;
  late final List<StreamSubscription<Object?>> _subscriptions;
  List<Song> _songs = const [];
  int _currentIndex = -1;
  Song? _currentSong;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerStatus _status = PlayerStatus.idle;
  String? _errorMessage;
  bool _isDisposed = false;

  Song? get currentSong => _currentSong;
  List<Song> get currentSongs => List.unmodifiable(_songs);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayerStatus get status => _status;
  String? get errorMessage => _errorMessage;

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
      final loadedDuration = await _engine.setFilePath(song.path);
      if (_isDisposed) return;
      if (loadedDuration != null) _duration = loadedDuration;
      _status = PlayerStatus.ready;
      notifyListeners();
      await _engine.play();
    } catch (error) {
      if (_isDisposed) return;
      _setError(_readableError(error));
    }
  }

  Future<void> play() async {
    if (_currentSong == null) return;
    try {
      await _engine.play();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> pause() async {
    try {
      await _engine.pause();
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
      await _engine.seek(safePosition);
      _position = safePosition;
      notifyListeners();
    } catch (error) {
      _setError(_readableError(error));
    }
  }

  Future<void> next() async {
    if (_songs.isEmpty || _currentIndex >= _songs.length - 1) return;
    await playSong(_songs[_currentIndex + 1], _songs);
  }

  Future<void> previous() async {
    if (_songs.isEmpty) return;
    if (_currentIndex <= 0) {
      await seek(Duration.zero);
      return;
    }
    await playSong(_songs[_currentIndex - 1], _songs);
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
    _isDisposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(_engine.dispose());
    super.dispose();
  }
}
