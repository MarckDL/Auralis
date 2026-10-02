import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/history_controller.dart';

void main() {
  test('records plays without duplicating the same song entry', () {
    final history = HistoryController();
    final first = DateTime(2026, 1, 1, 10);
    final second = first.add(const Duration(minutes: 2));

    history.record(songA, now: first);
    history.record(songA, now: second);
    history.record(songB, now: second.add(const Duration(minutes: 1)));

    expect(history.entries, hasLength(2));
    expect(history.recentlyPlayed.first.song, songB);
    expect(history.entries.first.playCount, 2);
  });

  test('sorts most played by count and then recency', () {
    final history = HistoryController();
    final now = DateTime(2026);

    history.record(songA, now: now);
    history.record(songB, now: now.add(const Duration(minutes: 1)));
    history.record(songB, now: now.add(const Duration(minutes: 2)));

    expect(history.mostPlayed.map((entry) => entry.song), [songB, songA]);
  });
}

const songA = Song(
  id: 'a', title: 'Alpha', artist: 'Artist A', album: 'Album A',
  duration: Duration(minutes: 3), path: '/music/a.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);
const songB = Song(
  id: 'b', title: 'Beta', artist: 'Artist B', album: 'Album B',
  duration: Duration(minutes: 4), path: '/music/b.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);
