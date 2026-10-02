import 'package:flutter/foundation.dart';

import '../models/song.dart';

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
  final List<HistoryEntry> _entries = <HistoryEntry>[];

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

  void record(Song song, {DateTime? now}) {
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
  }
}
