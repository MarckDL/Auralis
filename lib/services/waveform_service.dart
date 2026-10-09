import 'dart:async';
import 'dart:io';

import 'package:just_waveform/just_waveform.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

typedef WaveformDirectoryProvider = Future<Directory> Function();
typedef WaveformExtractor = Future<Waveform?> Function(
  File audioFile,
  File waveformFile,
);

class WaveformService {
  WaveformService({
    WaveformDirectoryProvider? directoryProvider,
    WaveformExtractor? extractor,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory,
       _extractor = extractor ?? _defaultExtractor;

  static const pixelsPerSecond = 20;

  final WaveformDirectoryProvider _directoryProvider;
  final WaveformExtractor _extractor;
  final Map<String, Waveform> _memoryCache = {};
  final Map<String, _WaveformJob> _pending = {};
  final List<_WaveformJob> _queue = [];
  bool _processing = false;
  String? _activeKey;

  Future<Waveform?> load(Song song, {bool priority = true}) async {
    final prepared = await _prepare(song);
    if (prepared == null) return null;

    final memory = _memoryCache[prepared.key];
    if (memory != null) return memory;

    final existing = _pending[prepared.key];
    if (existing != null) {
      if (priority && _activeKey != prepared.key) {
        _queue
          ..remove(existing)
          ..insert(0, existing);
      }
      return existing.completer.future;
    }

    if (await prepared.waveformFile.exists()) {
      try {
        final waveform = await JustWaveform.parse(prepared.waveformFile);
        _memoryCache[prepared.key] = waveform;
        return waveform;
      } catch (_) {
        await _deleteIfPresent(prepared.waveformFile);
      }
    }

    final queuedWhileReading = _pending[prepared.key];
    if (queuedWhileReading != null) return queuedWhileReading.completer.future;

    final job = _WaveformJob(prepared);
    _pending[prepared.key] = job;
    priority ? _queue.insert(0, job) : _queue.add(job);
    unawaited(_drainQueue());
    return job.completer.future;
  }

  void prefetch(Song current, List<Song> queue, {int lookAhead = 2}) {
    unawaited(load(current));
    final currentIndex = queue.indexWhere((song) => song.id == current.id);
    if (currentIndex < 0) return;
    final end = (currentIndex + lookAhead + 1).clamp(0, queue.length);
    for (var index = currentIndex + 1; index < end; index++) {
      unawaited(load(queue[index], priority: false));
    }
  }

  Future<void> prune(List<Song> availableSongs) async {
    final directory = await _waveformDirectory();
    if (!await directory.exists()) return;
    final validPaths = <String>{};
    for (final song in availableSongs) {
      final prepared = await _prepare(song, cleanObsolete: false);
      if (prepared != null) validPaths.add(prepared.waveformFile.path);
    }
    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.path.endsWith('.wave') &&
          !validPaths.contains(entity.path)) {
        await _deleteIfPresent(entity);
      }
    }
  }

  Future<void> _drainQueue() async {
    if (_processing) return;
    _processing = true;
    while (_queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _activeKey = job.prepared.key;
      Waveform? waveform;
      try {
        waveform = await _extractor(
          job.prepared.audioFile,
          job.prepared.waveformFile,
        );
        if (waveform != null) {
          _memoryCache[job.prepared.key] = waveform;
        }
      } catch (_) {
        await _deleteIfPresent(job.prepared.waveformFile);
      } finally {
        _pending.remove(job.prepared.key);
        if (!job.completer.isCompleted) job.completer.complete(waveform);
      }
    }
    _activeKey = null;
    _processing = false;
  }

  Future<_PreparedWaveform?> _prepare(
    Song song, {
    bool cleanObsolete = true,
  }) async {
    if (song.isRemote) return null;
    final audioFile = File(song.path);
    if (!await audioFile.exists()) return null;
    final stat = await audioFile.stat();
    final directory = await _waveformDirectory();
    final pathHash = _stableHash(song.path);
    final key = _stableHash(
      '${song.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}|$pixelsPerSecond',
    );
    final waveformFile = File(
      '${directory.path}${Platform.pathSeparator}wf_${pathHash}_$key.wave',
    );

    if (cleanObsolete) {
      final prefix = 'wf_${pathHash}_';
      await for (final entity in directory.list()) {
        if (entity is File &&
            entity.path != waveformFile.path &&
            entity.uri.pathSegments.last.startsWith(prefix)) {
          await _deleteIfPresent(entity);
        }
      }
    }
    return _PreparedWaveform(
      key: key,
      audioFile: audioFile,
      waveformFile: waveformFile,
    );
  }

  Future<Directory> _waveformDirectory() async {
    final root = await _directoryProvider();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}waveforms',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<Directory> _defaultDirectory() =>
      getApplicationSupportDirectory();

  static Future<Waveform?> _defaultExtractor(
    File audioFile,
    File waveformFile,
  ) async {
    Waveform? waveform;
    await for (final progress in JustWaveform.extract(
      audioInFile: audioFile,
      waveOutFile: waveformFile,
      zoom: const WaveformZoom.pixelsPerSecond(pixelsPerSecond),
    )) {
      waveform = progress.waveform ?? waveform;
    }
    return waveform;
  }

  static String _stableHash(String value) {
    var hash = 0xCBF29CE484222325;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001B3) & 0x7FFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  static Future<void> _deleteIfPresent(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The cache is disposable; failed cleanup must never block playback.
    }
  }
}

class _PreparedWaveform {
  const _PreparedWaveform({
    required this.key,
    required this.audioFile,
    required this.waveformFile,
  });

  final String key;
  final File audioFile;
  final File waveformFile;
}

class _WaveformJob {
  _WaveformJob(this.prepared);

  final _PreparedWaveform prepared;
  final Completer<Waveform?> completer = Completer<Waveform?>();
}
