import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/favorites_controller.dart';
import 'package:auralis/services/favorites_repository.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('auralis_favorites_test_');
    file = File('${directory.path}/favorites.json');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  FavoritesRepository repository() => FavoritesRepository(fileProvider: () async => file);

  test('returns an empty set when the file does not exist', () async {
    expect(await repository().loadFavoriteIds(), isEmpty);
  });

  test('saves and loads favorite IDs with duplicates removed', () async {
    await repository().saveFavoriteIds({'song-b', 'song-a'});
    expect(jsonDecode(await file.readAsString()), {
      'version': 1,
      'favoriteIds': ['song-a', 'song-b'],
    });
    await file.writeAsString(jsonEncode({
      'version': 1,
      'favoriteIds': ['song-b', 'song-a', 'song-a'],
    }));

    expect(await repository().loadFavoriteIds(), {'song-a', 'song-b'});
  });

  test('returns an empty set when JSON is corrupt', () async {
    await file.writeAsString('{not valid json');

    expect(await repository().loadFavoriteIds(), isEmpty);
  });

  test('controller adds, removes and restores favorites', () async {
    final controller = FavoritesController(repository: repository());
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();
    await controller.addFavorite(songA);
    expect(controller.isFavorite(songA), isTrue);
    await controller.removeFavorite(songA);
    expect(controller.isFavorite(songA), isFalse);
    await controller.toggleFavorite(songA);
    expect(controller.isFavorite(songA), isTrue);
    expect(notifications, greaterThan(0));
    controller.dispose();

    final restored = FavoritesController(repository: repository());
    await restored.load();
    expect(restored.isFavorite(songA), isTrue);
    restored.dispose();
  });

  test('controller reports storage errors and rolls back the change', () async {
    final controller = FavoritesController(
      repository: FavoritesRepository(
        fileProvider: () async => throw StateError('storage unavailable'),
      ),
    );
    await controller.load();
    await controller.addFavorite(songA);

    expect(controller.status, FavoritesStatus.error);
    expect(controller.isFavorite(songA), isFalse);
    expect(controller.errorMessage, contains('storage unavailable'));
    controller.dispose();
  });

}

const songA = Song(
  id: 'song-a',
  title: 'Song A',
  artist: 'Artist',
  album: 'Album',
  duration: Duration(minutes: 3),
  path: '/music/a.mp3',
  format: 'mp3',
  mimeType: 'audio/mpeg',
);
