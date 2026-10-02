import '../models/song.dart';

class ArtistSummary {
  const ArtistSummary({required this.name, required this.songs});

  final String name;
  final List<Song> songs;
}

class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.name,
    required this.artist,
    required this.songs,
  });

  final String id;
  final String name;
  final String artist;
  final List<Song> songs;

  Duration get totalDuration => songs.fold(
        Duration.zero,
        (total, song) => total + song.duration,
      );
}

class GenreSummary {
  const GenreSummary({required this.name, required this.songs});

  final String name;
  final List<Song> songs;
}

class MusicCatalog {
  MusicCatalog(List<Song> songs) : _songs = List.unmodifiable(songs);

  static const unknownArtist = 'Unknown artist';
  static const unknownAlbum = 'Unknown album';
  static const unknownGenre = 'Unknown genre';

  final List<Song> _songs;

  List<ArtistSummary> get artists => _groupBy(
        (song) => song.artist.trim().isEmpty ? unknownArtist : song.artist,
        ArtistSummary.new,
      );

  List<AlbumSummary> get albums {
    final grouped = <String, List<Song>>{};
    final labels = <String, ({String name, String artist})>{};
    for (final song in _songs) {
      final artist = _displayArtist(song.artist);
      final album = _displayAlbum(song.album);
      final id = '${artist.toLowerCase()}\u0000${album.toLowerCase()}';
      grouped.putIfAbsent(id, () => []).add(song);
      labels.putIfAbsent(id, () => (name: album, artist: artist));
    }
    return grouped.entries
        .map((entry) => AlbumSummary(
              id: entry.key,
              name: labels[entry.key]!.name,
              artist: labels[entry.key]!.artist,
              songs: List.unmodifiable(entry.value),
            ))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<GenreSummary> get genres => _groupBy(
        (song) => song.genre.trim().isEmpty ? unknownGenre : song.genre,
        GenreSummary.new,
      );

  List<Song> songsForArtist(String artist) {
    final key = _normalise(artist);
    return _songs
        .where((song) => _normalise(_displayArtist(song.artist)) == key)
        .toList(growable: false);
  }

  List<Song> songsForAlbum(String albumId) {
    return albums.firstWhere(
      (album) => album.id == albumId,
      orElse: () => const AlbumSummary(
        id: '',
        name: unknownAlbum,
        artist: unknownArtist,
        songs: [],
      ),
    ).songs;
  }

  List<Song> songsForGenre(String genre) {
    final key = _normalise(genre);
    return _songs
        .where((song) => _normalise(_displayGenre(song.genre)) == key)
        .toList(growable: false);
  }

  List<T> _groupBy<T extends Object>(
    String Function(Song song) labelFor,
    T Function({required String name, required List<Song> songs}) create,
  ) {
    final grouped = <String, List<Song>>{};
    final labels = <String, String>{};
    for (final song in _songs) {
      final label = labelFor(song);
      final key = _normalise(label);
      grouped.putIfAbsent(key, () => []).add(song);
      labels.putIfAbsent(key, () => label);
    }
    return grouped.entries
        .map((entry) => create(
              name: labels[entry.key]!,
              songs: List.unmodifiable(entry.value),
            ))
        .toList()
      ..sort((a, b) => _summaryName(a).toLowerCase().compareTo(_summaryName(b).toLowerCase()));
  }

  String _summaryName(Object summary) => switch (summary) {
        ArtistSummary value => value.name,
        GenreSummary value => value.name,
        _ => '',
      };

  static String _displayArtist(String value) =>
      value.trim().isEmpty ? unknownArtist : value.trim();
  static String _displayAlbum(String value) =>
      value.trim().isEmpty ? unknownAlbum : value.trim();
  static String _displayGenre(String value) =>
      value.trim().isEmpty ? unknownGenre : value.trim();
  static String _normalise(String value) => value.trim().toLowerCase();
}
