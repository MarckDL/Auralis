import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/history_controller.dart';
import 'package:auralis/services/statistics_controller.dart';

void main() {
  test('records plays, artists, genres and listening time', () async {
    final statistics = StatisticsController(repository: MemoryHistoryStore());
    await statistics.recordSongStarted(songA);
    await statistics.recordPosition(songA, const Duration(seconds: 2), true);
    await statistics.recordPosition(songA, const Duration(seconds: 4), true);
    await statistics.recordSongStarted(songA);

    expect(statistics.songsPlayed, 2);
    expect(statistics.listeningTime, const Duration(seconds: 4));
    expect(statistics.topArtists['Artist A'], 2);
    expect(statistics.topGenres['Rock'], 2);
  });

  test('ignores duplicate or backwards position intervals', () async {
    final statistics = StatisticsController(repository: MemoryHistoryStore());
    await statistics.recordSongStarted(songA);
    await statistics.recordPosition(songA, const Duration(seconds: 3), true);
    await statistics.recordPosition(songA, const Duration(seconds: 3), true);
    await statistics.recordPosition(songA, const Duration(seconds: 1), true);

    expect(statistics.listeningTime, const Duration(seconds: 3));
  });

  test('resets the position baseline after seek', () async {
    final statistics = StatisticsController(repository: MemoryHistoryStore());
    await statistics.recordSongStarted(songA);
    await statistics.recordPosition(songA, const Duration(seconds: 4), true);
    statistics.resetPosition(songA, const Duration(minutes: 2));
    await statistics.recordPosition(songA, const Duration(minutes: 2, seconds: 1), true);

    expect(statistics.listeningTime, const Duration(seconds: 5));
  });

  test('loads persisted statistics', () async {
    final store = MemoryHistoryStore();
    final first = StatisticsController(repository: store);
    await first.recordSongStarted(songA);
    await first.recordPosition(songA, const Duration(seconds: 5), true);

    final restored = StatisticsController(repository: store);
    await restored.load();
    expect(restored.songsPlayed, 1);
    expect(restored.listeningTime, const Duration(seconds: 5));
  });
}

const songA = Song(
  id: 'stats-a', title: 'Stats A', artist: 'Artist A', album: 'Album A',
  duration: Duration(minutes: 3), path: '/music/stats-a.mp3', format: 'mp3',
  mimeType: 'audio/mpeg', genre: 'Rock',
);
