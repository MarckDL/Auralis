import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:auralis/models/playlist.dart';
import 'package:auralis/models/song.dart';
import 'package:auralis/services/auralis_database.dart';
import 'package:auralis/services/favorites_repository.dart';
import 'package:auralis/services/history_controller.dart';
import 'package:auralis/services/playlists_repository.dart';

void main() {
  late Directory directory;
  late String path;
  late AuralisDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('auralis_database_test_');
    path = '${directory.path}/auralis.db';
    database = await AuralisDatabase.open(path: path, factory: databaseFactoryFfi);
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('creates the schema and persists songs, favorites, playlists and history', () async {
    await database.upsertSongs([songA, songB]);
    await database.favoritesStore.saveFavoriteIds({'a'});
    final now = DateTime(2026);
    await database.playlistsStore.savePlaylists([
      Playlist(
        id: 'playlist',
        name: 'Test playlist',
        songIds: const ['b', 'a'],
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final history = HistoryController(repository: database.historyStore);
    await history.record(songB, now: now);

    expect(await database.favoritesStore.loadFavoriteIds(), {'a'});
    expect((await database.playlistsStore.loadPlaylists()).single.songIds, ['b', 'a']);
    expect((await history.repositoryEntries()).single.song, songB);
  });

  test('keeps history count after reopening the database', () async {
    await database.upsertSongs([songA]);
    final history = HistoryController(repository: database.historyStore);
    await history.record(songA, now: DateTime(2026));
    await history.record(songA, now: DateTime(2026, 1, 2));
    await database.close();
    database = await AuralisDatabase.open(path: path, factory: databaseFactoryFfi);

    final restored = HistoryController(repository: database.historyStore);
    await restored.load();
    expect(restored.entries.single.playCount, 2);
  });

  test('migrates legacy JSON stores only once and preserves order', () async {
    final favorites = _MemoryFavoritesStore({'a'});
    final now = DateTime(2026);
    final playlists = _MemoryPlaylistsStore([
      Playlist(
        id: 'legacy',
        name: 'Legacy',
        songIds: const ['b', 'a'],
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await database.migrateLegacyData(favorites: favorites, playlists: playlists);
    await database.migrateLegacyData(
      favorites: _MemoryFavoritesStore({'b'}),
      playlists: _MemoryPlaylistsStore(const []),
    );

    expect(await database.favoritesStore.loadFavoriteIds(), {'a'});
    expect((await database.playlistsStore.loadPlaylists()).single.songIds, ['b', 'a']);
  });
}

extension on HistoryController {
  Future<List<HistoryEntry>> repositoryEntries() async {
    return entries;
  }
}

class _MemoryFavoritesStore implements FavoritesStore {
  _MemoryFavoritesStore(this.ids);
  final Set<String> ids;

  @override
  Future<Set<String>> loadFavoriteIds() async => ids;

  @override
  Future<void> saveFavoriteIds(Set<String> value) async {}
}

class _MemoryPlaylistsStore implements PlaylistsStore {
  _MemoryPlaylistsStore(this.playlists);
  final List<Playlist> playlists;

  @override
  Future<List<Playlist>> loadPlaylists() async => playlists;

  @override
  Future<void> savePlaylists(List<Playlist> value) async {}
}

const songA = Song(
  id: 'a', title: 'Song A', artist: 'Artist A', album: 'Album A',
  duration: Duration(minutes: 3), path: '/music/a.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);
const songB = Song(
  id: 'b', title: 'Song B', artist: 'Artist B', album: 'Album B',
  duration: Duration(minutes: 4), path: '/music/b.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);
