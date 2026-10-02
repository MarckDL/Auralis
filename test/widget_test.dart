import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_audio_scan/local_audio_scan.dart';

import 'package:auralis/main.dart';
import 'package:auralis/models/song.dart';
import 'package:auralis/services/audio_handler.dart';
import 'package:auralis/services/favorites_controller.dart';
import 'package:auralis/services/favorites_repository.dart';
import 'package:auralis/services/history_controller.dart';
import 'package:auralis/services/music_scanner.dart';
import 'package:auralis/services/player_controller.dart';
import 'package:auralis/services/statistics_controller.dart';

void main() {
  testWidgets('shows the Auralis home screen', (WidgetTester tester) async {
    await tester.pumpWidget(AuralisApp(playbackGateway: FakePlaybackGateway()));

    expect(find.text('Your sound,\nyour space.'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Midnight Signals'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('uses the light theme and switches appearance from Settings', (WidgetTester tester) async {
    await tester.pumpWidget(AuralisApp(playbackGateway: FakePlaybackGateway()));

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness, Brightness.light);
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.dark_mode_outlined).last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
  });

  testWidgets('navigates between the main sections', (WidgetTester tester) async {
    await tester.pumpWidget(AuralisApp(playbackGateway: FakePlaybackGateway()));

    await tester.tap(find.text('Playlists'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Preferences'), findsOneWidget);
  });

  testWidgets('renders songs returned by the scanner', (WidgetTester tester) async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(tracks: [_track('Song A', 'a.mp3')]),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LibraryScreen(scanner: scanner))),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 songs'), findsOneWidget);
    expect(find.text('Song A'), findsOneWidget);
  });

  testWidgets('filters the scanned library by title', (WidgetTester tester) async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(
        tracks: [
          _track('Song A', 'a.mp3'),
          _track('Different Song', 'b.mp3'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LibraryScreen(scanner: scanner))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'song a');
    await tester.pump();

    expect(find.text('1 songs'), findsOneWidget);
    expect(find.text('Song A'), findsOneWidget);
    expect(find.text('Different Song'), findsNothing);
  });

  testWidgets('shows an empty state when search has no matches', (WidgetTester tester) async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(tracks: [_track('Song A', 'a.mp3')]),
    );

    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryScreen(
            scanner: scanner,
            onSearchCleared: () => cleared = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();

    expect(find.text('No matches found'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect((tester.widget<TextField>(find.byType(TextField)).controller?.text), isEmpty);
    expect(cleared, isTrue);
  });

  testWidgets('shows persisted listening statistics', (WidgetTester tester) async {
    final statistics = StatisticsController(repository: MemoryHistoryStore());
    await statistics.recordSongStarted(_catalogSong('stats', 'Artist', 'Album'));

    await tester.pumpWidget(
      MaterialApp(home: StatisticsScreen(controller: statistics)),
    );

    expect(find.text('1 plays'), findsOneWidget);
    expect(find.text('Top artists'), findsOneWidget);
    expect(find.text('Artist'), findsWidgets);
    statistics.dispose();
  });

  testWidgets('Home forwards search and See all actions', (WidgetTester tester) async {
    final statistics = StatisticsController(repository: MemoryHistoryStore());
    await statistics.recordSongStarted(_catalogSong('history', 'Artist', 'Album'));
    String? searchQuery;
    var openedHistory = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            onOpenPlayer: () {},
            history: statistics,
            onSearch: (value) => searchQuery = value,
            onSeeAll: () => openedHistory = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'luna');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.tap(find.text('See all'));

    expect(searchQuery, 'luna');
    expect(openedHistory, isTrue);
    statistics.dispose();
  });

  testWidgets('route scaffold shows the global Mini Player', (WidgetTester tester) async {
    final gateway = FakePlaybackGateway();
    final player = PlayerController(gateway: gateway);
    final favorites = FavoritesController(repository: _MemoryFavoritesRepository());
    await player.playSong(_catalogSong('playing', 'Artist', 'Album'), [
      _catalogSong('playing', 'Artist', 'Album'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: AuralisPlayerScope(
          controller: player,
          favorites: favorites,
          onOpenPlayer: () {},
          child: const AuralisRouteScaffold(
            body: Center(child: Text('Detail')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Song playing'), findsOneWidget);
    player.dispose();
    favorites.dispose();
  });

  testWidgets('shows a permission state when access is denied',
      (WidgetTester tester) async {
    final scanner = MusicScanner(
      gateway: FakeAudioScannerGateway(permission: false, requestResult: false),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LibraryScreen(scanner: scanner))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Music permission required'), findsOneWidget);
    expect(find.text('Allow access'), findsOneWidget);
  });

  testWidgets('browses artists and opens the artist detail', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryBrowseView(
            category: 'Artists',
            songs: [_catalogSong('a', 'Luna Vale', 'Afterglow')],
          ),
        ),
      ),
    );

    expect(find.text('Luna Vale'), findsOneWidget);
    await tester.tap(find.text('Luna Vale'));
    await tester.pumpAndSettle();
    expect(find.text('Songs'), findsOneWidget);
  });

  testWidgets('browses albums and genres', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryBrowseView(
            category: 'Albums',
            songs: [_catalogSong('a', 'Luna Vale', 'Afterglow')],
          ),
        ),
      ),
    );
    expect(find.text('Afterglow'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryBrowseView(
            category: 'Genres',
            songs: [_catalogSong('a', 'Luna Vale', 'Afterglow')],
          ),
        ),
      ),
    );
    expect(find.text('Unknown genre'), findsOneWidget);
  });

  testWidgets('plays the complete artist collection from its detail', (tester) async {
    final songs = [
      _catalogSong('a', 'Luna Vale', 'Afterglow'),
      _catalogSong('b', 'Luna Vale', 'Afterglow'),
    ];
    List<Song>? selectedQueue;

    await tester.pumpWidget(
      MaterialApp(
        home: ArtistDetailScreen(
          artist: 'Luna Vale',
          songs: songs,
          onSongSelected: (song, queue) async => selectedQueue = queue,
        ),
      ),
    );

    await tester.tap(find.text('Play all'));
    expect(selectedQueue, songs);
    await tester.tap(find.text('Song b'));
    expect(selectedQueue, songs);
  });

  testWidgets('plays the complete genre collection from its detail', (tester) async {
    final songs = [
      _catalogSong('a', 'Artist A', 'Album A'),
      _catalogSong('b', 'Artist B', 'Album B'),
    ];
    List<Song>? selectedQueue;

    await tester.pumpWidget(
      MaterialApp(
        home: GenreDetailScreen(
          genre: 'Unknown genre',
          songs: songs,
          onSongSelected: (song, queue) async => selectedQueue = queue,
        ),
      ),
    );

    await tester.tap(find.text('Play all'));
    expect(selectedQueue, songs);
    await tester.tap(find.text('Song b'));
    expect(selectedQueue, songs);
  });

  testWidgets('plays the complete album and favorites collections', (tester) async {
    final songs = [
      _catalogSong('a', 'Luna Vale', 'Afterglow'),
      _catalogSong('b', 'Luna Vale', 'Afterglow'),
    ];
    List<Song>? selectedQueue;
    final favorites = FavoritesController(repository: _MemoryFavoritesRepository());
    await favorites.addFavorite(songs[0]);
    await favorites.addFavorite(songs[1]);

    await tester.pumpWidget(
      MaterialApp(
        home: AlbumDetailScreen(
          albumId: 'luna vale\u0000afterglow',
          songs: songs,
          onSongSelected: (song, queue) async => selectedQueue = queue,
        ),
      ),
    );
    await tester.tap(find.text('Play album'));
    expect(selectedQueue, songs);

    await tester.pumpWidget(
      MaterialApp(
        home: FavoritesScreen(
          songs: songs,
          favorites: favorites,
          onSongSelected: (song, queue) async => selectedQueue = queue,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Play favorites'));
    expect(selectedQueue, songs);
  });
}

class _MemoryFavoritesRepository extends FavoritesRepository {
  final Set<String> ids = <String>{};

  @override
  Future<Set<String>> loadFavoriteIds() async => Set<String>.of(ids);

  @override
  Future<void> saveFavoriteIds(Set<String> value) async {
    ids
      ..clear()
      ..addAll(value);
  }
}

class FakeAudioScannerGateway implements AudioScannerGateway {
  FakeAudioScannerGateway({
    this.tracks = const [],
    this.permission = true,
    this.requestResult = true,
  });

  final List<AudioTrack> tracks;
  final bool permission;
  final bool requestResult;

  @override
  Future<bool> checkPermission() async => permission;

  @override
  Future<bool> requestPermission() async => requestResult;

  @override
  Future<List<AudioTrack>> scanTracks() async => tracks;
}

AudioTrack _track(String title, String path) {
  return AudioTrack(
    id: title,
    title: title,
    artist: 'Artist',
    album: 'Album',
    duration: 125000,
    filePath: '/storage/emulated/0/Music/$path',
    mimeType: 'audio/mpeg',
    size: 1000,
    dateAdded: DateTime(2026),
  );
}

class FakePlaybackGateway implements PlaybackGateway {
  final _playback = StreamController<PlaybackState>.broadcast();
  final _media = StreamController<MediaItem?>.broadcast();
  final _queue = StreamController<List<MediaItem>>.broadcast();

  @override
  Stream<PlaybackState> get playbackStateStream => _playback.stream;
  @override
  Stream<MediaItem?> get mediaItemStream => _media.stream;
  @override
  Stream<List<MediaItem>> get queueStream => _queue.stream;
  @override
  Future<void> setQueue(List<Song> songs, int initialIndex) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> skipToNext() async {}
  @override
  Future<void> skipToPrevious() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {}
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {}
}

Song _catalogSong(String id, String artist, String album) {
  return Song(
    id: id,
    title: 'Song $id',
    artist: artist,
    album: album,
    duration: const Duration(minutes: 3),
    path: '/music/$id.mp3',
    format: 'mp3',
    mimeType: 'audio/mpeg',
  );
}
