import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/models/song.dart';
import 'package:auralis/services/music_catalog.dart';

void main() {
  test('groups artists and genres case-insensitively', () {
    final catalog = MusicCatalog([songA, songB, songC]);

    expect(catalog.artists.map((artist) => artist.name), ['Luna Vale']);
    expect(catalog.artists.single.songs, hasLength(3));
    expect(catalog.genres.map((genre) => genre.name), ['Rock', 'Unknown genre']);
  });

  test('keeps albums with the same name under different artists', () {
    final catalog = MusicCatalog([songA, songB, songD]);

    expect(catalog.albums, hasLength(2));
    expect(catalog.albums.map((album) => album.artist), ['Luna Vale', 'Northbound']);
    expect(catalog.songsForAlbum(catalog.albums.last.id), hasLength(1));
  });

  test('calculates album duration and resolves category songs', () {
    final catalog = MusicCatalog([songA, songB]);
    final album = catalog.albums.single;

    expect(album.totalDuration, const Duration(minutes: 5));
    expect(catalog.songsForArtist('lUnA vAlE'), hasLength(2));
    expect(catalog.songsForGenre('rock'), hasLength(2));
  });
}

const songA = Song(
  id: 'a', title: 'A', artist: 'Luna Vale', album: 'Afterglow',
  genre: 'Rock', duration: Duration(minutes: 3), path: '/a.mp3',
  format: 'mp3', mimeType: 'audio/mpeg',
);
const songB = Song(
  id: 'b', title: 'B', artist: 'luna vale', album: 'Afterglow',
  genre: 'rock', duration: Duration(minutes: 2), path: '/b.mp3',
  format: 'mp3', mimeType: 'audio/mpeg',
);
const songC = Song(
  id: 'c', title: 'C', artist: 'Luna Vale', album: 'Other',
  duration: Duration(minutes: 1), path: '/c.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);
const songD = Song(
  id: 'd', title: 'D', artist: 'Northbound', album: 'Afterglow',
  genre: 'Rock', duration: Duration(minutes: 4), path: '/d.mp3',
  format: 'mp3', mimeType: 'audio/mpeg',
);
