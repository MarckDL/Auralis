import 'package:flutter/foundation.dart';

import '../models/song.dart';

abstract interface class HistoryStore {
  Future<List<HistoryEntry>> loadHistory();

  Future<void> saveHistoryEntry(HistoryEntry entry);
}

class HistoryEntry {
  const HistoryEntry({
    required this.song,
    required this.playedAt,
    required this.playCount,
  });

  final Song song;
  final DateTime playedAt;
  final int playCount;

  HistoryEntry copyWith({DateTime? playedAt, int? playCount}) {
    return HistoryEntry(
      song: song,
      playedAt: playedAt ?? this.playedAt,
      playCount: playCount ?? this.playCount,
    );
  }
}

class HistoryController extends ChangeNotifier {
  HistoryController({HistoryStore? repository})
      : _repository = repository ?? _MemoryHistoryStore();

  final HistoryStore _repository;
  final List<HistoryEntry> _entries = <HistoryEntry>[];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  List<HistoryEntry> get recentlyPlayed {
    return [..._entries]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  List<HistoryEntry> get mostPlayed {
    return [..._entries]
      ..sort((a, b) {
        final count = b.playCount.compareTo(a.playCount);
        return count == 0 ? b.playedAt.compareTo(a.playedAt) : count;
      });
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _entries
      ..clear()
      ..addAll(await _repository.loadHistory());
    _isLoading = false;
    notifyListeners();
  }

  Future<void> record(Song song, {DateTime? now}) async {
    final playedAt = now ?? DateTime.now();
    final index = _entries.indexWhere((entry) => entry.song.id == song.id);
    if (index == -1) {
      _entries.add(HistoryEntry(song: song, playedAt: playedAt, playCount: 1));
    } else {
      final entry = _entries[index];
      _entries[index] = entry.copyWith(
        playedAt: playedAt,
        playCount: entry.playCount + 1,
      );
    }
    notifyListeners();
    await _repository.saveHistoryEntry(
      _entries.firstWhere((entry) => entry.song.id == song.id),
    );
  }
}

class _MemoryHistoryStore implements HistoryStore {
  final List<HistoryEntry> _entries = <HistoryEntry>[];

  @override
  Future<List<HistoryEntry>> loadHistory() async => List.unmodifiable(_entries);

  @override
  Future<void> saveHistoryEntry(HistoryEntry entry) async {
    final index = _entries.indexWhere((item) => item.song.id == entry.song.id);
    if (index == -1) {
      _entries.add(entry);
    } else {
      _entries[index] = entry;
    }
  }
}
