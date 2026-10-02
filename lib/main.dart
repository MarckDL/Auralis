import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'models/song.dart';
import 'models/playlist.dart';
import 'services/audio_handler.dart';
import 'services/favorites_controller.dart';
import 'services/player_controller.dart';
import 'services/music_scanner.dart';
import 'services/music_catalog.dart';
import 'services/playlists_controller.dart';
import 'services/history_controller.dart';
import 'services/auralis_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final handler = await AudioService.init(
    builder: AuralisAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.auralis.auralis.playback',
      androidNotificationChannelName: 'Auralis Playback',
      androidNotificationChannelDescription: 'Controls for Auralis playback',
      androidStopForegroundOnPause: false,
    ),
  );
  final database = await AuralisDatabase.open();
  await database.migrateLegacyData();
  runApp(AuralisApp(playbackGateway: handler, database: database));
}

class AuralisApp extends StatelessWidget {
  const AuralisApp({required this.playbackGateway, this.database, super.key});

  final PlaybackGateway playbackGateway;
  final AuralisDatabase? database;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9B8CFF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Auralis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101018),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF171722),
          indicatorColor: colorScheme.primary.withValues(alpha: 0.22),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: colorScheme.onSurface),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B1B27),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: AuralisShell(playbackGateway: playbackGateway, database: database),
    );
  }
}

class MockSong {
  const MockSong({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.color,
  });

  final String title;
  final String artist;
  final String album;
  final String duration;
  final Color color;
}

const mockSongs = [
  MockSong(
    title: 'Midnight Signals',
    artist: 'Luna Vale',
    album: 'Afterglow',
    duration: '3:42',
    color: Color(0xFF5C4B8A),
  ),
  MockSong(
    title: 'Drift',
    artist: 'Northbound',
    album: 'Open Skies',
    duration: '4:18',
    color: Color(0xFF3F7480),
  ),
  MockSong(
    title: 'Glass Houses',
    artist: 'Mira Sol',
    album: 'Refractions',
    duration: '3:09',
    color: Color(0xFF8C5B65),
  ),
  MockSong(
    title: 'Quiet Motion',
    artist: 'The Signals',
    album: 'Soft Focus',
    duration: '5:01',
    color: Color(0xFF66734D),
  ),
];

class AuralisShell extends StatefulWidget {
  const AuralisShell({required this.playbackGateway, this.database, super.key});

  final PlaybackGateway playbackGateway;
  final AuralisDatabase? database;

  @override
  State<AuralisShell> createState() => _AuralisShellState();
}

class _AuralisShellState extends State<AuralisShell> {
  int _selectedIndex = 0;
  late final PlayerController _playerController;
  late final FavoritesController _favoritesController;
  late final PlaylistsController _playlistsController;
  late final HistoryController _historyController;
  List<Song> _availableSongs = const [];

  static const _titles = ['Good evening', 'Library', 'Playlists', 'Settings'];

  @override
  void initState() {
    super.initState();
    _historyController = HistoryController(
      repository: widget.database?.historyStore,
    );
    _playerController = PlayerController(
      gateway: widget.playbackGateway,
      onSongStarted: _historyController.record,
    );
    _favoritesController = FavoritesController(
      repository: widget.database?.favoritesStore,
    );
    _playlistsController = PlaylistsController(
      playerController: _playerController,
      repository: widget.database?.playlistsStore,
    );
    unawaited(_favoritesController.load());
    unawaited(_playlistsController.load());
    unawaited(_historyController.load());
  }

  @override
  void dispose() {
    _playerController.dispose();
    _historyController.dispose();
    _favoritesController.dispose();
    _playlistsController.dispose();
    if (widget.database != null) unawaited(widget.database!.close());
    super.dispose();
  }

  void _openPlayer() {
    if (_playerController.currentSong == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          controller: _playerController,
          favorites: _favoritesController,
        ),
      ),
    );
  }

  Future<void> _playSong(Song song, List<Song> songs) {
    return _playerController.playSong(song, songs);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenPlayer: _openPlayer,
        history: _historyController,
        availableSongs: _availableSongs,
        favorites: _favoritesController,
        onSongSelected: _playSong,
      ),
      LibraryScreen(
        favorites: _favoritesController,
        onSongsChanged: (songs) {
          if (mounted) setState(() => _availableSongs = songs);
          if (widget.database != null) unawaited(widget.database!.upsertSongs(songs));
        },
        onSongSelected: _playSong,
      ),
      PlaylistsScreen(
        controller: _playlistsController,
        availableSongs: _availableSongs,
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: _playerController,
        builder: (context, _) => MiniPlayer(
              controller: _playerController,
              favorites: _favoritesController,
              onTap: _openPlayer,
            ),
          ),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music_rounded),
                label: 'Playlists',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onOpenPlayer,
    required this.history,
    this.availableSongs = const [],
    this.favorites,
    this.onSongSelected,
    super.key,
  });

  final VoidCallback onOpenPlayer;
  final HistoryController history;
  final List<Song> availableSongs;
  final FavoritesController? favorites;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
        Text(
          'Your sound,\nyour space.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
        ),
        const SizedBox(height: 22),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search your music',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 28),
        SectionHeader(
          title: 'Recently played',
          actionLabel: history.recentlyPlayed.isNotEmpty ? 'See all' : null,
        ),
        const SizedBox(height: 12),
        if (history.recentlyPlayed.isNotEmpty)
          ...history.recentlyPlayed.take(3).map(
                (entry) => RealSongCard(
                  song: entry.song,
                  favorites: favorites,
                  onTap: onSongSelected == null
                      ? null
                      : () => onSongSelected!(entry.song, [entry.song]),
                ),
              )
        else ...[
          SongCard(song: mockSongs[0], onTap: onOpenPlayer),
          SongCard(song: mockSongs[1], onTap: onOpenPlayer),
        ],
        if (availableSongs.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Recently added'),
          const SizedBox(height: 12),
          ...([...availableSongs]
                ..sort((a, b) => (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0))))
              .take(3)
              .map(
                (song) => RealSongCard(
                  song: song,
                  favorites: favorites,
                  onTap: onSongSelected == null
                      ? null
                      : () => onSongSelected!(song, availableSongs),
                ),
              ),
        ],
        if (history.mostPlayed.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Most played'),
          const SizedBox(height: 12),
          ...history.mostPlayed.take(3).map(
                (entry) => ListTile(
                  leading: SongArtwork(song: entry.song, size: 44),
                  title: Text(entry.song.title),
                  subtitle: Text('${entry.song.artist} · ${entry.playCount} plays'),
                  onTap: onSongSelected == null
                      ? null
                      : () => onSongSelected!(entry.song, [entry.song]),
                ),
              ),
        ],
        const SizedBox(height: 24),
        const SectionHeader(title: 'Made for you'),
        const SizedBox(height: 12),
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, index) => AlbumCard(
              title: ['Afterglow', 'Open Skies', 'Refractions'][index],
              subtitle: ['Luna Vale', 'Northbound', 'Mira Sol'][index],
              color: mockSongs[index].color,
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    this.scanner,
    this.favorites,
    this.onSongsChanged,
    this.onSongSelected,
    super.key,
  });

  final MusicScanner? scanner;
  final FavoritesController? favorites;
  final ValueChanged<List<Song>>? onSongsChanged;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final MusicScanner _scanner;
  MusicScanResult? _result;
  bool _isLoading = true;
  String _selectedCategory = 'Songs';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scanner = widget.scanner ?? MusicScanner();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    final result = await _scanner.scan();
    if (!mounted) return;
    setState(() {
      _result = result;
      _isLoading = false;
    });
    if (result.status == MusicScanStatus.success) {
      widget.onSongsChanged?.call(result.songs);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your library', style: Theme.of(context).textTheme.titleLarge),
            if (widget.favorites != null)
              TextButton.icon(
                onPressed: () => _openFavorites(context),
                icon: const Icon(Icons.favorite_rounded, size: 18),
                label: const Text('Favorites'),
              ),
          ],
        ),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search songs, artists or albums',
            prefixIcon: Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Songs', 'Artists', 'Albums', 'Genres']
              .map((label) => FilterChip(
                    label: Text(label),
                    selected: label == _selectedCategory,
                    onSelected: (_) => setState(() => _selectedCategory = label),
                  ))
              .toList(),
        ),
        const SizedBox(height: 22),
        if (_isLoading)
          const _LibraryLoading()
        else
          _buildResult(context, _result!),
      ],
    );
  }

  Widget _buildResult(BuildContext context, MusicScanResult result) {
    switch (result.status) {
      case MusicScanStatus.success:
        final filteredSongs = _filterSongs(result.songs);
        if (filteredSongs.isEmpty && _searchQuery.isNotEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matches found',
            message: 'Try another title, artist or album.',
            actionLabel: 'Clear search',
            onAction: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          );
        }
        if (_selectedCategory != 'Songs') {
          return CategoryBrowseView(
            category: _selectedCategory,
            songs: filteredSongs,
            favorites: widget.favorites,
            onSongSelected: widget.onSongSelected,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${filteredSongs.length} songs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...filteredSongs.map(
              (song) => RealSongCard(
                song: song,
                favorites: widget.favorites,
                onTap: widget.onSongSelected == null
                    ? null
                    : () => widget.onSongSelected!(song, filteredSongs),
              ),
            ),
          ],
        );
      case MusicScanStatus.empty:
        return EmptyState(
          icon: Icons.library_music_outlined,
          title: 'Your library is empty',
          message: 'Add music to your device and scan again.',
          actionLabel: 'Scan again',
          onAction: _loadLibrary,
        );
      case MusicScanStatus.permissionDenied:
        return EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Music permission required',
          message: 'Auralis needs access to your audio files to build Library.',
          actionLabel: 'Allow access',
          onAction: _loadLibrary,
        );
      case MusicScanStatus.error:
        return EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load your library',
          message: result.message ?? 'Try scanning again.',
          actionLabel: 'Retry',
          onAction: _loadLibrary,
        );
    }
  }

  List<Song> _filterSongs(List<Song> songs) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return songs;
    return songs.where((song) {
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          song.album.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  void _openFavorites(BuildContext context) {
    final songs = _result?.songs ?? const <Song>[];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FavoritesScreen(
          songs: songs,
          favorites: widget.favorites!,
          onSongSelected: widget.onSongSelected,
        ),
      ),
    );
  }
}

class _LibraryLoading extends StatelessWidget {
  const _LibraryLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 18),
          Text('Scanning music on this device...'),
        ],
      ),
    );
  }
}

class CategoryBrowseView extends StatelessWidget {
  const CategoryBrowseView({
    required this.category,
    required this.songs,
    this.favorites,
    this.onSongSelected,
    super.key,
  });

  final String category;
  final List<Song> songs;
  final FavoritesController? favorites;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  Widget build(BuildContext context) {
    final catalog = MusicCatalog(songs);
    if (category == 'Artists') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: catalog.artists
            .map(
              (artist) => Card(
                child: ListTile(
                  leading: SongArtwork(song: artist.songs.first, size: 52),
                  title: Text(artist.name),
                  subtitle: Text('${artist.songs.length} songs'),
                  trailing: IconButton(
                    tooltip: 'Play all',
                    onPressed: onSongSelected == null || artist.songs.isEmpty
                        ? null
                        : () => onSongSelected!(artist.songs.first, artist.songs),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistDetailScreen(
                        artist: artist.name,
                        songs: songs,
                        favorites: favorites,
                        onSongSelected: onSongSelected,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    }
    if (category == 'Albums') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: catalog.albums
            .map(
              (album) => Card(
                child: ListTile(
                  leading: SongArtwork(song: album.songs.first, size: 52),
                  title: Text(album.name),
                  subtitle: Text('${album.artist} · ${album.songs.length} songs'),
                  trailing: IconButton(
                    tooltip: 'Play album',
                    onPressed: onSongSelected == null || album.songs.isEmpty
                        ? null
                        : () => onSongSelected!(album.songs.first, album.songs),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlbumDetailScreen(
                        albumId: album.id,
                        songs: songs,
                        favorites: favorites,
                        onSongSelected: onSongSelected,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: catalog.genres
          .map(
            (genre) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.category_rounded)),
                title: Text(genre.name),
                subtitle: Text('${genre.songs.length} songs'),
                trailing: IconButton(
                  tooltip: 'Play all',
                  onPressed: onSongSelected == null || genre.songs.isEmpty
                      ? null
                      : () => onSongSelected!(genre.songs.first, genre.songs),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GenreDetailScreen(
                      genre: genre.name,
                      songs: songs,
                      favorites: favorites,
                      onSongSelected: onSongSelected,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({
    required this.artist,
    required this.songs,
    this.favorites,
    this.onSongSelected,
    super.key,
  });

  final String artist;
  final List<Song> songs;
  final FavoritesController? favorites;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  Widget build(BuildContext context) {
    final artistSongs = MusicCatalog(songs).songsForArtist(artist);
    final albums = MusicCatalog(artistSongs).albums;
    return Scaffold(
      appBar: AppBar(title: Text(artist)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('${artistSongs.length} songs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: artistSongs.isEmpty || onSongSelected == null
                ? null
                : () => onSongSelected!(artistSongs.first, artistSongs),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play all'),
          ),
          if (albums.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Albums', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...albums.map(
              (album) => ListTile(
                leading: SongArtwork(song: album.songs.first, size: 48),
                title: Text(album.name),
                subtitle: Text('${album.songs.length} songs · ${_durationLabel(album.totalDuration)}'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Songs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...artistSongs.map(
            (song) => RealSongCard(
              song: song,
              favorites: favorites,
              onTap: onSongSelected == null
                  ? null
                  : () => onSongSelected!(song, artistSongs),
            ),
          ),
        ],
      ),
    );
  }
}

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({
    required this.albumId,
    required this.songs,
    this.favorites,
    this.onSongSelected,
    super.key,
  });

  final String albumId;
  final List<Song> songs;
  final FavoritesController? favorites;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  Widget build(BuildContext context) {
    final album = MusicCatalog(songs).albums.firstWhere(
          (item) => item.id == albumId,
          orElse: () => const AlbumSummary(
            id: '',
            name: MusicCatalog.unknownAlbum,
            artist: MusicCatalog.unknownArtist,
            songs: [],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(album.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (album.songs.isNotEmpty) SongArtwork(song: album.songs.first, size: 180),
          const SizedBox(height: 16),
          Text(album.name, style: Theme.of(context).textTheme.headlineSmall),
          Text(album.artist),
          Text('${album.songs.length} songs · ${_durationLabel(album.totalDuration)}'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: album.songs.isEmpty || onSongSelected == null
                ? null
                : () => onSongSelected!(album.songs.first, album.songs),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play album'),
          ),
          const SizedBox(height: 12),
          ...album.songs.map(
            (song) => RealSongCard(
              song: song,
              favorites: favorites,
              onTap: onSongSelected == null
                  ? null
                  : () => onSongSelected!(song, album.songs),
            ),
          ),
        ],
      ),
    );
  }
}

class GenreDetailScreen extends StatelessWidget {
  const GenreDetailScreen({
    required this.genre,
    required this.songs,
    this.favorites,
    this.onSongSelected,
    super.key,
  });

  final String genre;
  final List<Song> songs;
  final FavoritesController? favorites;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  Widget build(BuildContext context) {
    final genreSongs = MusicCatalog(songs).songsForGenre(genre);
    return Scaffold(
      appBar: AppBar(title: Text(genre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('${genreSongs.length} songs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: genreSongs.isEmpty || onSongSelected == null
                ? null
                : () => onSongSelected!(genreSongs.first, genreSongs),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play all'),
          ),
          const SizedBox(height: 12),
          ...genreSongs.map(
            (song) => RealSongCard(
              song: song,
              favorites: favorites,
              onTap: onSongSelected == null
                  ? null
                  : () => onSongSelected!(song, genreSongs),
            ),
          ),
        ],
      ),
    );
  }
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({
    required this.controller,
    required this.availableSongs,
    super.key,
  });

  final PlaylistsController controller;
  final List<Song> availableSongs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.status == PlaylistsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your playlists', style: Theme.of(context).textTheme.titleLarge),
                FilledButton.tonalIcon(
                  onPressed: () => _showPlaylistDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
            if (controller.status == PlaylistsStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  controller.errorMessage ?? 'Could not load playlists.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            if (controller.playlists.isEmpty)
              EmptyState(
                icon: Icons.queue_music_rounded,
                title: 'No playlists yet',
                message: 'Create a playlist to keep your favorite moods together.',
                actionLabel: 'Create playlist',
                onAction: () => _showPlaylistDialog(context),
              )
            else
              ...controller.playlists.map(
                (playlist) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.queue_music_rounded),
                    ),
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.songIds.length} songs'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PlaylistDetailScreen(
                          controller: controller,
                          playlistId: playlist.id,
                          availableSongs: availableSongs,
                        ),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _showPlaylistDialog(context, playlist);
                        if (value == 'delete') _confirmDelete(context, playlist);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit name')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showPlaylistDialog(BuildContext context, [Playlist? playlist]) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => PlaylistNameDialog(
        initialName: playlist?.name ?? '',
        title: playlist == null ? 'New playlist' : 'Edit playlist',
      ),
    );
    if (name == null) return;
    if (playlist == null) {
      await controller.createPlaylist(name);
    } else {
      await controller.renamePlaylist(playlist.id, name);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${playlist.name}?'),
        content: const Text('This playlist and its song order will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await controller.deletePlaylist(playlist.id);
  }
}

class PlaylistNameDialog extends StatefulWidget {
  const PlaylistNameDialog({
    required this.initialName,
    required this.title,
    super.key,
  });

  final String initialName;
  final String title;

  @override
  State<PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<PlaylistNameDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({
    required this.controller,
    required this.playlistId,
    required this.availableSongs,
    super.key,
  });

  final PlaylistsController controller;
  final String playlistId;
  final List<Song> availableSongs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final playlist = controller.findById(playlistId);
        if (playlist == null) {
          return const Scaffold(body: Center(child: Text('Playlist not found')));
        }
        final songs = controller.songsFor(playlist, availableSongs);
        final missingCount = playlist.songIds.length - songs.length;
        return Scaffold(
          appBar: AppBar(title: Text(playlist.name)),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('${songs.length} available songs')),
                    FilledButton.tonalIcon(
                      onPressed: songs.isEmpty
                          ? null
                          : () => controller.playPlaylist(playlist.id, availableSongs),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play'),
                    ),
                  ],
                ),
              ),
              if (missingCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    '$missingCount song(s) are not available in the current library.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: songs.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    final oldSongId = playlist.songIds[oldIndex];
                    final oldPlaylistIndex = playlist.songIds.indexOf(oldSongId);
                    final newPlaylistIndex = newIndex >= playlist.songIds.length
                        ? playlist.songIds.length
                        : newIndex;
                    controller.reorderSongs(playlist.id, oldPlaylistIndex, newPlaylistIndex);
                  },
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      key: ValueKey(song.id),
                      leading: SongArtwork(song: song, size: 48),
                      title: Text(song.title),
                      subtitle: Text(song.artist),
                      trailing: IconButton(
                        tooltip: 'Remove from playlist',
                        onPressed: () => controller.removeSong(playlist.id, song.id),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showSongSelector(context, playlist),
            icon: const Icon(Icons.add),
            label: const Text('Add songs'),
          ),
        );
      },
    );
  }

  Future<void> _showSongSelector(BuildContext context, Playlist playlist) async {
    final selectedIds = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final candidates = availableSongs
              .where((song) => !playlist.songIds.contains(song.id))
              .toList(growable: false);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.75,
              child: Column(
                children: [
                  const ListTile(
                    title: Text('Add songs'),
                    subtitle: Text('Select songs for this playlist'),
                  ),
                  Expanded(
                    child: candidates.isEmpty
                        ? const Center(child: Text('No other songs available'))
                        : ListView.builder(
                            itemCount: candidates.length,
                            itemBuilder: (_, index) {
                              final song = candidates[index];
                              return CheckboxListTile(
                                value: selectedIds.contains(song.id),
                                onChanged: (selected) => setModalState(() {
                                  if (selected == true) {
                                    selectedIds.add(song.id);
                                  } else {
                                    selectedIds.remove(song.id);
                                  }
                                }),
                                title: Text(song.title),
                                subtitle: Text(song.artist),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: selectedIds.isEmpty
                          ? null
                          : () async {
                              for (final song in candidates.where((song) => selectedIds.contains(song.id))) {
                                await controller.addSong(playlist.id, song);
                              }
                              if (context.mounted) Navigator.pop(context);
                            },
                      child: Text('Add ${selectedIds.length} songs'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    required this.songs,
    required this.favorites,
    this.onSongSelected,
    super.key,
  });

  final List<Song> songs;
  final FavoritesController favorites;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ListenableBuilder(
        listenable: favorites,
        builder: (context, _) {
          final favoriteSongs = songs
              .where(favorites.isFavorite)
              .toList(growable: false);
          if (favoriteSongs.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No favorites yet',
              message: 'Tap the heart on a song to save it here.',
              actionLabel: 'Back to library',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: FilledButton.icon(
                  onPressed: onSongSelected == null
                      ? null
                      : () => onSongSelected!(favoriteSongs.first, favoriteSongs),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play favorites'),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: favoriteSongs.length,
                  itemBuilder: (context, index) => RealSongCard(
                    song: favoriteSongs[index],
                    favorites: favorites,
                    onTap: onSongSelected == null
                        ? null
                        : () => onSongSelected!(favoriteSongs[index], favoriteSongs),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const SettingsTile(
          icon: Icons.dark_mode_outlined,
          title: 'Appearance',
          subtitle: 'Dark theme',
        ),
        const SettingsTile(
          icon: Icons.storage_outlined,
          title: 'Music folders',
          subtitle: 'Configured in a future sprint',
        ),
        const SettingsTile(
          icon: Icons.info_outline_rounded,
          title: 'About Auralis',
          subtitle: 'Sprint 1 · UI preview',
        ),
      ],
    );
  }
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    required this.controller,
    required this.favorites,
    super.key,
  });

  final PlayerController controller;
  final FavoritesController favorites;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        if (song == null) {
          return const Scaffold(
            body: Center(child: Text('No song selected')),
          );
        }

        final maxDuration = controller.duration.inMilliseconds > 0
            ? controller.duration
            : const Duration(seconds: 1);
        final position = controller.position > maxDuration
            ? maxDuration
            : controller.position;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Now playing'),
            centerTitle: true,
            actions: [
              ListenableBuilder(
                listenable: favorites,
                builder: (context, _) => IconButton(
                  onPressed: () => favorites.toggleFavorite(song),
                  tooltip: favorites.isFavorite(song)
                      ? 'Remove favorite'
                      : 'Add favorite',
                  icon: Icon(
                    favorites.isFavorite(song)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
            child: Column(
              children: [
                SongArtwork(song: song, size: 290),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    song.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    song.artist,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 42),
                if (controller.status == PlayerStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      controller.errorMessage ?? 'Unable to play this song.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: maxDuration.inMilliseconds.toDouble(),
                  onChanged: controller.status == PlayerStatus.loading
                      ? null
                      : (value) => controller.seek(
                            Duration(milliseconds: value.round()),
                          ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(controller.position)),
                    Text(_formatDuration(controller.duration)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: controller.toggleShuffle,
                      tooltip: 'Shuffle',
                      color: controller.shuffleMode == AudioServiceShuffleMode.all
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      icon: const Icon(Icons.shuffle_rounded),
                    ),
                    IconButton(
                      onPressed: controller.previous,
                      iconSize: 36,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    FloatingActionButton(
                      onPressed: controller.status == PlayerStatus.loading
                          ? null
                          : controller.togglePlayPause,
                      child: controller.status == PlayerStatus.loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              controller.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    IconButton(
                      onPressed: controller.next,
                      iconSize: 36,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                    IconButton(
                      onPressed: controller.cycleRepeatMode,
                      tooltip: 'Repeat',
                      color: controller.repeatMode == AudioServiceRepeatMode.none
                          ? null
                          : Theme.of(context).colorScheme.primary,
                      icon: Icon(
                        controller.repeatMode == AudioServiceRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showQueue(context),
                  icon: const Icon(Icons.queue_music_rounded),
                  label: Text('Queue (${controller.currentSongs.length})'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const ListTile(
              title: Text('Play queue'),
              subtitle: Text('Temporary queue for this session'),
            ),
            ...controller.currentSongs.asMap().entries.map(
                  (entry) => ListTile(
                    selected: entry.key == controller.currentIndex,
                    leading: SongArtwork(song: entry.value, size: 44),
                    title: Text(entry.value.title),
                    subtitle: Text(entry.value.artist),
                    onTap: () {
                      Navigator.pop(context);
                      controller.playSong(entry.value, controller.currentSongs);
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class SongCard extends StatelessWidget {
  const SongCard({required this.song, this.onTap, super.key});

  final MockSong song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: AlbumArtwork(color: song.color, size: 52),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${song.artist} · ${song.album}'),
      trailing: Text(song.duration),
      onTap: onTap,
    );
  }
}

class RealSongCard extends StatelessWidget {
  const RealSongCard({
    required this.song,
    this.favorites,
    this.onTap,
    super.key,
  });

  final Song song;
  final FavoritesController? favorites;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: SongArtwork(song: song, size: 52),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${song.artist} · ${song.album}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (favorites != null)
            FavoriteButton(song: song, favorites: favorites!),
          Text(song.durationLabel),
        ],
      ),
      onTap: onTap,
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({required this.song, required this.favorites, super.key});

  final Song song;
  final FavoritesController favorites;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) => IconButton(
        onPressed: () => favorites.toggleFavorite(song),
        tooltip: favorites.isFavorite(song)
            ? 'Remove favorite'
            : 'Add favorite',
        icon: Icon(
          favorites.isFavorite(song)
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: favorites.isFavorite(song)
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    required this.title,
    required this.subtitle,
    required this.color,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumArtwork(color: color, size: 138),
          const SizedBox(height: 8),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({required this.color, required this.size, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 70 ? 18 : 12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.62)!],
        ),
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        size: size * 0.34,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}

class SongArtwork extends StatelessWidget {
  const SongArtwork({required this.song, required this.size, super.key});

  final Song song;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (song.hasArtwork) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size > 70 ? 18 : 12),
        child: Image.memory(
          song.artwork!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackArtwork(),
        ),
      );
    }
    return _fallbackArtwork();
  }

  Widget _fallbackArtwork() {
    final color = Colors.primaries[song.title.hashCode.abs() % Colors.primaries.length];
    return AlbumArtwork(color: color, size: size);
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.controller,
    required this.favorites,
    required this.onTap,
    super.key,
  });

  final PlayerController controller;
  final FavoritesController favorites;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong;
    if (song == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ListTile(
        onTap: onTap,
        leading: SongArtwork(song: song, size: 44),
        title: Text(song.title),
        subtitle: Text(song.artist),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FavoriteButton(song: song, favorites: favorites),
            IconButton(
              onPressed: controller.togglePlayPause,
              tooltip: controller.isPlaying ? 'Pause' : 'Play',
              icon: Icon(
                controller.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.actionLabel, super.key});

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (actionLabel != null)
          TextButton(onPressed: () {}, child: Text(actionLabel!)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 22),
          FilledButton(onPressed: onAction ?? () {}, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
