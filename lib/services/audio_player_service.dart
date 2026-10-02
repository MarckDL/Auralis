import 'package:just_audio/just_audio.dart';

class AudioEngineError {
  const AudioEngineError(this.message);

  final String message;
}

abstract interface class AudioEngine {
  Stream<bool> get playingStream;

  Stream<Duration> get positionStream;

  Stream<Duration?> get durationStream;

  Stream<AudioEngineError> get errorStream;

  Future<Duration?> setFilePath(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<AudioEngineError> get errorStream => _player.errorStream.map(
      (error) => AudioEngineError(
        error.message ?? 'Unable to play this song.',
      ),
      );

  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
