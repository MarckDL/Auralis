import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import 'favorites_repository.dart';
import 'history_controller.dart';
import 'playlists_repository.dart';

class AuralisDatabase {
  AuralisDatabase._(this._db);

  final Database _db;

  static Future<AuralisDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final databasePath = path ?? '${await getDatabasesPath()}/auralis.db';
    final database = await (factory ?? databaseFactory).openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async => _createSchema(db),
      ),
    );
    return AuralisDatabase._(database);
  }

  FavoritesStore get favoritesStore => _DatabaseFavoritesStore(this);
  PlaylistsStore get playlistsStore => _DatabasePlaylistsStore(this);
  HistoryStore get historyStore => _DatabaseHistoryStore(this);

  Future<void> migrateLegacyData({
    FavoritesStore? favorites,
    PlaylistsStore? playlists,
  }) async {
    final marker = await _db.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['legacy_json_migrated'],
      limit: 1,
    );
    if (marker.isNotEmpty) return;

    final favoriteIds = await (favorites ?? FavoritesRepository()).loadFavoriteIds();
    final oldPlaylists = await (playlists ?? PlaylistsRepository()).loadPlaylists();
    await _db.transaction((transaction) async {
      for (final id in favoriteIds) {
        await transaction.insert(
          'favorites',
          {'song_id': id},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final playlist in oldPlaylists) {
        await transaction.insert(
          'playlists',
          {
            'id': playlist.id,
            'name': playlist.name,
            'created_at': playlist.createdAt.millisecondsSinceEpoch,
            'updated_at': playlist.updatedAt.millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        for (var index = 0; index < playlist.songIds.length; index++) {
          await transaction.insert(
            'playlist_songs',
            {
              'playlist_id': playlist.id,
              'song_id': playlist.songIds[index],
              'position': index,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      await transaction.insert('metadata', {
        'key': 'legacy_json_migrated',
        'value': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> upsertSongs(List<Song> songs) async {
    await _db.transaction((transaction) async {
      for (final song in songs) {
        await transaction.insert(
          'songs',
          _songValues(song),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await transaction.delete('artists');
      await transaction.delete('albums');
      final artistCounts = <String, int>{};
      final albumCounts = <String, int>{};
      for (final song in songs) {
        final artist = song.artist.trim();
        final album = '${artist.toLowerCase()}\u0000${song.album.toLowerCase()}';
        artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
        albumCounts[album] = (albumCounts[album] ?? 0) + 1;
      }
      for (final entry in artistCounts.entries) {
        await transaction.insert('artists', {
          'name': entry.key,
          'song_count': entry.value,
        });
      }
      for (final entry in albumCounts.entries) {
        final parts = entry.key.split('\u0000');
        await transaction.insert('albums', {
          'id': entry.key,
          'name': parts.last,
          'artist': parts.first,
          'song_count': entry.value,
        });
      }
    });
  }

  Future<void> close() => _db.close();

  Future<List<Map<String, Object?>>> query(String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) {
    return _db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<void> transaction(Future<void> Function(Transaction transaction) action) {
    return _db.transaction(action);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''CREATE TABLE songs(
      id TEXT PRIMARY KEY, title TEXT NOT NULL, artist TEXT NOT NULL,
      album TEXT NOT NULL, duration_ms INTEGER NOT NULL, path TEXT NOT NULL,
      format TEXT NOT NULL, mime_type TEXT NOT NULL, genre TEXT NOT NULL,
      date_added INTEGER, artwork BLOB)''');
    await db.execute('''CREATE TABLE artists(
      name TEXT PRIMARY KEY, song_count INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE albums(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, artist TEXT NOT NULL,
      song_count INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE playlists(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE playlist_songs(
      playlist_id TEXT NOT NULL, song_id TEXT NOT NULL, position INTEGER NOT NULL,
      PRIMARY KEY (playlist_id, song_id),
      FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE favorites(
      song_id TEXT PRIMARY KEY)''');
    await db.execute('''CREATE TABLE history(
      song_id TEXT PRIMARY KEY, played_at INTEGER NOT NULL,
      play_count INTEGER NOT NULL,
      FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE metadata(
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
  }
}

Map<String, Object?> _songValues(Song song) => {
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'duration_ms': song.duration.inMilliseconds,
      'path': song.path,
      'format': song.format,
      'mime_type': song.mimeType,
      'genre': song.genre,
      'date_added': song.dateAdded?.millisecondsSinceEpoch,
      'artwork': song.artwork,
    };

Song _songFromRow(Map<String, Object?> row) => Song(
      id: row['id']! as String,
      title: row['title']! as String,
      artist: row['artist']! as String,
      album: row['album']! as String,
      duration: Duration(milliseconds: row['duration_ms']! as int),
      path: row['path']! as String,
      format: row['format']! as String,
      mimeType: row['mime_type']! as String,
      genre: row['genre']! as String,
      dateAdded: row['date_added'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['date_added']! as int),
      artwork: row['artwork'] == null ? null : Uint8List.fromList(row['artwork']! as List<int>),
    );

class _DatabaseFavoritesStore implements FavoritesStore {
  _DatabaseFavoritesStore(this.database);
  final AuralisDatabase database;

  @override
  Future<Set<String>> loadFavoriteIds() async {
    final rows = await database.query('favorites');
    return rows.map((row) => row['song_id']! as String).toSet();
  }

  @override
  Future<void> saveFavoriteIds(Set<String> ids) {
    return database.transaction((transaction) async {
      await transaction.delete('favorites');
      for (final id in ids) {
        await transaction.insert('favorites', {'song_id': id});
      }
    });
  }
}

class _DatabasePlaylistsStore implements PlaylistsStore {
  _DatabasePlaylistsStore(this.database);
  final AuralisDatabase database;

  @override
  Future<List<Playlist>> loadPlaylists() async {
    final rows = await database.query('playlists', orderBy: 'created_at ASC');
    final result = <Playlist>[];
    for (final row in rows) {
      final songs = await database.query(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: [row['id']],
        orderBy: 'position ASC',
      );
      result.add(Playlist(
        id: row['id']! as String,
        name: row['name']! as String,
        songIds: songs.map((song) => song['song_id']! as String).toList(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
      ));
    }
    return result;
  }

  @override
  Future<void> savePlaylists(List<Playlist> playlists) {
    return database.transaction((transaction) async {
      await transaction.delete('playlist_songs');
      await transaction.delete('playlists');
      for (final playlist in playlists) {
        await transaction.insert('playlists', {
          'id': playlist.id,
          'name': playlist.name,
          'created_at': playlist.createdAt.millisecondsSinceEpoch,
          'updated_at': playlist.updatedAt.millisecondsSinceEpoch,
        });
        for (var index = 0; index < playlist.songIds.length; index++) {
          await transaction.insert('playlist_songs', {
            'playlist_id': playlist.id,
            'song_id': playlist.songIds[index],
            'position': index,
          });
        }
      }
    });
  }
}

class _DatabaseHistoryStore implements HistoryStore {
  _DatabaseHistoryStore(this.database);
  final AuralisDatabase database;

  @override
  Future<List<HistoryEntry>> loadHistory() async {
    final rows = await database.query('history', orderBy: 'played_at DESC');
    final result = <HistoryEntry>[];
    for (final row in rows) {
      final songs = await database.query('songs', where: 'id = ?', whereArgs: [row['song_id']], orderBy: 'id');
      if (songs.isEmpty) continue;
      result.add(HistoryEntry(
        song: _songFromRow(songs.first),
        playedAt: DateTime.fromMillisecondsSinceEpoch(row['played_at']! as int),
        playCount: row['play_count']! as int,
      ));
    }
    return result;
  }

  @override
  Future<void> saveHistoryEntry(HistoryEntry entry) async {
    await database.transaction((transaction) async {
      await transaction.insert('songs', _songValues(entry.song), conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.insert('history', {
        'song_id': entry.song.id,
        'played_at': entry.playedAt.millisecondsSinceEpoch,
        'play_count': entry.playCount,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
