import 'package:flutter/foundation.dart';

import '../models/song.dart';
import 'history_controller.dart';

class StatisticsController extends ChangeNotifier {
  StatisticsController({HistoryStore? repository})
      : _repository = repository ?? MemoryHistoryStore();

  final HistoryStore _repository;
  final List<HistoryEntry> _entries = <HistoryEntry>[];
  final Map<String, Duration> _lastPositions = <String, Duration>{};
  Future<void> _pendingWrite = Future<void>.value();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<HistoryEntry> get entries => List.unmodifiable(_entries);
  int get songsPlayed => _entries.fold(0, (total, entry) => total + entry.playCount);
  Duration get listeningTime => _entries.fold(
        Duration.zero,
        (total, entry) => total + entry.listenedDuration,
      );

  List<HistoryEntry> get recentlyPlayed => [..._entries]
    ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

  List<HistoryEntry> get mostPlayed => [..._entries]
    ..sort((a, b) {
      final count = b.playCount.compareTo(a.playCount);
      return count == 0 ? b.playedAt.compareTo(a.playedAt) : count;
    });

  Map<String, int> get topArtists => _countsBy((entry) => entry.song.artist);
  Map<String, int> get topGenres => _countsBy((entry) => entry.song.genre);

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _entries
        ..clear()
        ..addAll(await _repository.loadHistory());
    } catch (error) {
      _errorMessage = _readableError(error);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> recordSongStarted(Song song) async {
    final now = DateTime.now();
    final index = _entries.indexWhere((entry) => entry.song.id == song.id);
    if (index == -1) {
      _entries.add(HistoryEntry(song: song, playedAt: now, playCount: 1));
    } else {
      final entry = _entries[index];
      _entries[index] = entry.copyWith(
        playedAt: now,
        playCount: entry.playCount + 1,
      );
    }
    _lastPositions[song.id] = Duration.zero;
    notifyListeners();
    await _queueSave(_entries.lastWhere((entry) => entry.song.id == song.id));
  }

  Future<void> recordPosition(Song song, Duration position, bool isPlaying) async {
    final previous = _lastPositions[song.id];
    _lastPositions[song.id] = position;
    if (!isPlaying || previous == null) return;
    final delta = position - previous;
    if (delta <= Duration.zero || delta > const Duration(seconds: 5)) return;
    final index = _entries.indexWhere((entry) => entry.song.id == song.id);
    if (index == -1) return;
    final entry = _entries[index];
    final updated = entry.copyWith(listenedDuration: entry.listenedDuration + delta);
    _entries[index] = updated;
    notifyListeners();
    await _queueSave(updated);
  }

  void resetPosition(Song song, Duration position) {
    _lastPositions[song.id] = position;
  }

  Map<String, int> _countsBy(String Function(HistoryEntry entry) label) {
    final counts = <String, int>{};
    for (final entry in _entries) {
      final key = label(entry);
      counts[key] = (counts[key] ?? 0) + entry.playCount;
    }
    return Map.unmodifiable(counts);
  }

  Future<void> _queueSave(HistoryEntry entry) {
    _pendingWrite = _pendingWrite.then((_) => _save(entry));
    return _pendingWrite;
  }

  Future<void> _save(HistoryEntry entry) async {
    try {
      await _repository.saveHistoryEntry(entry);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _readableError(error);
      notifyListeners();
    }
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Could not load statistics.' : message;
  }
}
