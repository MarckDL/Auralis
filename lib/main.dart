import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/song.dart';
import 'models/playlist.dart';
import 'services/audio_handler.dart';
import 'services/favorites_controller.dart';
import 'services/player_controller.dart';
import 'services/music_scanner.dart';
import 'services/music_catalog.dart';
import 'services/playlists_controller.dart';
import 'services/auralis_database.dart';
import 'services/sleep_timer_controller.dart';
import 'services/statistics_controller.dart';

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

class AuralisApp extends StatefulWidget {
  const AuralisApp({required this.playbackGateway, this.database, super.key});

  final PlaybackGateway playbackGateway;
  final AuralisDatabase? database;

  @override
  State<AuralisApp> createState() => _AuralisAppState();
}

class _AuralisAppState extends State<AuralisApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auralis',
      debugShowCheckedModeBanner: false,
      theme: _auralisTheme(Brightness.light),
      darkTheme: _auralisTheme(Brightness.dark),
      themeMode: _themeMode,
      home: AuralisShell(
        playbackGateway: widget.playbackGateway,
        database: widget.database,
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

ThemeData _auralisTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7657E8),
    brightness: brightness,
  );
  final surface = isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1B1B24);
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: isLight ? const Color(0xFFF5F6F8) : const Color(0xFF101018),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 25,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: isLight ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: isLight ? 0.06 : 0.25),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isLight ? const Color(0xFF171719) : const Color(0xFF171722),
      height: 68,
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(color: isLight ? Colors.white : scheme.onSurface)),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: isLight ? Colors.white70 : scheme.onSurfaceVariant)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 8,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
  );
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
  const AuralisShell({
    required this.playbackGateway,
    this.database,
    this.themeMode = ThemeMode.light,
    this.onThemeModeChanged,
    super.key,
  });

  final PlaybackGateway playbackGateway;
  final AuralisDatabase? database;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<AuralisShell> createState() => _AuralisShellState();
}

class _AuralisShellState extends State<AuralisShell> {
  int _selectedIndex = 0;
  late final PlayerController _playerController;
  late final FavoritesController _favoritesController;
  late final PlaylistsController _playlistsController;
  late final StatisticsController _statisticsController;
  late final SleepTimerController _sleepTimerController;
  List<Song> _availableSongs = const [];
  String _librarySearchQuery = '';
  bool _playerOpen = false;

  static const _titles = ['Good evening', 'Library', 'Playlists', 'Settings'];

  @override
  void initState() {
    super.initState();
    _statisticsController = StatisticsController(
      repository: widget.database?.historyStore,
    );
    _playerController = PlayerController(
      gateway: widget.playbackGateway,
      onSongStarted: _statisticsController.recordSongStarted,
      onPositionChanged: _statisticsController.recordPosition,
      onSeek: _statisticsController.resetPosition,
      onPlaybackCompleted: () async => _sleepTimerController.handleSongCompleted(),
    );
    _sleepTimerController = SleepTimerController(playerController: _playerController);
    _favoritesController = FavoritesController(
      repository: widget.database?.favoritesStore,
    );
    _playlistsController = PlaylistsController(
      playerController: _playerController,
      repository: widget.database?.playlistsStore,
    );
    unawaited(_favoritesController.load());
    unawaited(_playlistsController.load());
    unawaited(_statisticsController.load());
  }

  @override
  void dispose() {
    _playerController.dispose();
    _statisticsController.dispose();
    _sleepTimerController.dispose();
    _favoritesController.dispose();
    _playlistsController.dispose();
    if (widget.database != null) unawaited(widget.database!.close());
    super.dispose();
  }

  void _openPlayer() {
    if (_playerController.currentSong == null) return;
    if (_playerOpen) return;
    _playerOpen = true;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          controller: _playerController,
          favorites: _favoritesController,
          sleepTimer: _sleepTimerController,
          availableSongs: _availableSongs,
        ),
      ),
    ).whenComplete(() => _playerOpen = false);
  }

  Future<void> _playSong(Song song, List<Song> songs) async {
    await _requestNotificationPermission();
    await _playerController.playSong(song, songs);
    if (mounted && !_playerOpen) _openPlayer();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) await Permission.notification.request();
    } catch (_) {
      // Some non-Android targets do not expose notification permissions.
    }
  }

  void _openLibrarySearch(String query) {
    setState(() {
      _librarySearchQuery = query;
      _selectedIndex = 1;
    });
  }

  void _clearLibrarySearch() {
    if (_librarySearchQuery.isEmpty) return;
    setState(() => _librarySearchQuery = '');
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(controller: _statisticsController),
      ),
    );
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailScreen(
          controller: _playlistsController,
          playlistId: playlist.id,
          availableSongs: _availableSongs,
          onSongSelected: _playSong,
        ),
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const PlaylistNameDialog(
        initialName: '',
        title: 'New playlist',
      ),
    );
    if (name != null) await _playlistsController.createPlaylist(name);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenPlayer: _openPlayer,
        history: _statisticsController,
        availableSongs: _availableSongs,
        favorites: _favoritesController,
        onSongSelected: _playSong,
        onSearch: _openLibrarySearch,
        onSeeAll: _openHistory,
        playlists: _playlistsController,
        onCreatePlaylist: () => _createPlaylist(context),
        onOpenPlaylist: _openPlaylist,
      ),
      LibraryScreen(
        favorites: _favoritesController,
        initialSearchQuery: _librarySearchQuery,
        onSearchCleared: _clearLibrarySearch,
        onSongsChanged: (songs) {
          if (mounted) setState(() => _availableSongs = songs);
          if (widget.database != null) unawaited(widget.database!.upsertSongs(songs));
        },
        onSongSelected: _playSong,
      ),
      PlaylistsScreen(
        controller: _playlistsController,
        availableSongs: _availableSongs,
        onSongSelected: _playSong,
      ),
      SettingsScreen(
        statistics: _statisticsController,
        sleepTimer: _sleepTimerController,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return AuralisPlayerScope(
      controller: _playerController,
      favorites: _favoritesController,
      onOpenPlayer: _openPlayer,
      child: Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.015, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: IndexedStack(
          key: ValueKey(_selectedIndex),
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerMiniBar(
            controller: _playerController,
            favorites: _favoritesController,
            onTap: _openPlayer,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      if (_selectedIndex == 1 && index != 1) {
                        _librarySearchQuery = '';
                      }
                      _selectedIndex = index;
                    });
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
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class AuralisPlayerScope extends InheritedWidget {
  const AuralisPlayerScope({
    required this.controller,
    required this.favorites,
    required this.onOpenPlayer,
    required super.child,
    super.key,
  });

  final PlayerController controller;
  final FavoritesController favorites;
  final VoidCallback onOpenPlayer;

  static AuralisPlayerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuralisPlayerScope>();
  }

  @override
  bool updateShouldNotify(AuralisPlayerScope oldWidget) =>
      controller != oldWidget.controller || favorites != oldWidget.favorites;
}

class PlayerMiniBar extends StatelessWidget {
  const PlayerMiniBar({
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
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MiniPlayer(
        controller: controller,
        favorites: favorites,
        onTap: onTap,
      ),
    );
  }
}

class AuralisRouteScaffold extends StatelessWidget {
  const AuralisRouteScaffold({
    required this.body,
    this.appBar,
    this.floatingActionButton,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final scope = AuralisPlayerScope.maybeOf(context);
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: scope == null
          ? null
          : PlayerMiniBar(
              controller: scope.controller,
              favorites: scope.favorites,
              onTap: scope.onOpenPlayer,
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
    this.onSearch,
    this.onSeeAll,
    this.playlists,
    this.onCreatePlaylist,
    this.onOpenPlaylist,
    super.key,
  });

  final VoidCallback onOpenPlayer;
  final StatisticsController history;
  final List<Song> availableSongs;
  final FavoritesController? favorites;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onSeeAll;
  final PlaylistsController? playlists;
  final VoidCallback? onCreatePlaylist;
  final ValueChanged<Playlist>? onOpenPlaylist;

  @override
  Widget build(BuildContext context) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          _greeting(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Music',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          onSubmitted: onSearch,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search your music',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 24),
        _HomeHistorySection(
          history: history,
          favorites: favorites,
          onSongSelected: onSongSelected,
          onOpenPlayer: onOpenPlayer,
          onSeeAll: onSeeAll,
        ),
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
        const SizedBox(height: 24),
        if (playlists != null && onCreatePlaylist != null && onOpenPlaylist != null)
          _HomePlaylistsSection(
            controller: playlists!,
            availableSongs: availableSongs,
            onCreatePlaylist: onCreatePlaylist!,
            onOpenPlaylist: onOpenPlaylist!,
          ),
        ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _HomeHistorySection extends StatelessWidget {
  const _HomeHistorySection({
    required this.history,
    required this.onOpenPlayer,
    this.favorites,
    this.onSongSelected,
    this.onSeeAll,
  });

  final StatisticsController history;
  final VoidCallback onOpenPlayer;
  final FavoritesController? favorites;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final recent = history.recentlyPlayed.take(3).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Recently played',
              actionLabel: recent.isNotEmpty ? 'See all' : null,
              onAction: onSeeAll,
            ),
            const SizedBox(height: 12),
            if (recent.isNotEmpty)
              ...recent.map(
                (entry) => RealSongCard(
                  song: entry.song,
                  favorites: favorites,
                  onTap: onSongSelected == null
                      ? null
                      : () => onSongSelected!(entry.song, [entry.song]),
                ),
              )
            else
              AuralisCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.history_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('No recent plays'),
                  subtitle: const Text('Start listening to build your history.'),
                ),
              ),
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
          ],
        );
      },
    );
  }

}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    this.scanner,
    this.favorites,
    this.onSongsChanged,
    this.onSongSelected,
    this.initialSearchQuery = '',
    this.onSearchCleared,
    super.key,
  });

  final MusicScanner? scanner;
  final FavoritesController? favorites;
  final ValueChanged<List<Song>>? onSongsChanged;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;
  final String initialSearchQuery;
  final VoidCallback? onSearchCleared;

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
    _searchQuery = widget.initialSearchQuery.trim();
    _searchController.text = _searchQuery;
    _loadLibrary();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSearchQuery != widget.initialSearchQuery &&
        widget.initialSearchQuery != _searchQuery) {
      _searchQuery = widget.initialSearchQuery.trim();
      _searchController.value = TextEditingValue(
        text: _searchQuery,
        selection: TextSelection.collapsed(offset: _searchQuery.length),
      );
    }
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
                      widget.onSearchCleared?.call();
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
              widget.onSearchCleared?.call();
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
            AlphabeticalList(
              items: [...filteredSongs]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
              labelFor: (song) => song.title,
              itemBuilder: (song) => RealSongCard(
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

class _HomePlaylistsSection extends StatelessWidget {
  const _HomePlaylistsSection({
    required this.controller,
    required this.availableSongs,
    required this.onCreatePlaylist,
    required this.onOpenPlaylist,
  });

  final PlaylistsController controller;
  final List<Song> availableSongs;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<Playlist> onOpenPlaylist;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final playlists = controller.playlists;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Your playlists',
              actionLabel: 'Create',
              onAction: onCreatePlaylist,
            ),
            const SizedBox(height: 10),
            if (playlists.isEmpty)
              AuralisCard(
                child: ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Create your first playlist'),
                  subtitle: const Text('Save songs for every mood.'),
                  trailing: IconButton(
                    onPressed: onCreatePlaylist,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              )
            else
              ...playlists.take(4).map((playlist) {
                final songs = controller.songsFor(playlist, availableSongs);
                return Card(
                  child: ListTile(
                    leading: songs.isEmpty
                        ? const CircleAvatar(child: Icon(Icons.queue_music_rounded))
                        : SongArtwork(song: songs.first, size: 52),
                    title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${songs.length} available songs'),
                    onTap: () => onOpenPlaylist(playlist),
                    trailing: IconButton(
                      tooltip: 'Play playlist',
                      onPressed: songs.isEmpty
                          ? null
                          : () => controller.playPlaylist(playlist.id, availableSongs),
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                  ),
                );
              }),
          ],
        );
      },
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

class AlphabeticalList<T> extends StatefulWidget {
  const AlphabeticalList({
    required this.items,
    required this.labelFor,
    required this.itemBuilder,
    super.key,
  });

  final List<T> items;
  final String Function(T item) labelFor;
  final Widget Function(T item) itemBuilder;

  @override
  State<AlphabeticalList<T>> createState() => _AlphabeticalListState<T>();
}

class _AlphabeticalListState<T> extends State<AlphabeticalList<T>> {
  final _scrollController = ScrollController();

  String _initial(String value) {
    final first = value.trim().toUpperCase();
    if (first.isEmpty) return '#';
    return RegExp(r'[A-Z]').hasMatch(first[0]) ? first[0] : '#';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initials = <String>{
      for (final item in widget.items) _initial(widget.labelFor(item)),
    }.toList()
      ..sort();
    return SizedBox(
      height: 500,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.items.length,
              itemBuilder: (_, index) => widget.itemBuilder(widget.items[index]),
            ),
          ),
          SizedBox(
            width: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: initials.map((letter) {
                final index = widget.items.indexWhere(
                  (item) => _initial(widget.labelFor(item)) == letter,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _scrollController.animateTo(
                    (index * 76).clamp(0, _scrollController.position.maxScrollExtent).toDouble(),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      letter,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
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
      return AlphabeticalList(
        items: [...catalog.artists]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        labelFor: (artist) => artist.name,
        itemBuilder: (artist) => Card(
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
    return AuralisRouteScaffold(
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
    return AuralisRouteScaffold(
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
    return AuralisRouteScaffold(
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
    this.onSongSelected,
    super.key,
  });

  final PlaylistsController controller;
  final List<Song> availableSongs;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

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
                          onSongSelected: onSongSelected,
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

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({
    required this.controller,
    required this.playlistId,
    required this.availableSongs,
    this.onSongSelected,
    super.key,
  });

  final PlaylistsController controller;
  final String playlistId;
  final List<Song> availableSongs;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _editing = false;

  PlaylistsController get controller => widget.controller;
  String get playlistId => widget.playlistId;
  List<Song> get availableSongs => widget.availableSongs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final playlist = controller.findById(playlistId);
        if (playlist == null) {
          return const AuralisRouteScaffold(body: Center(child: Text('Playlist not found')));
        }
        final songs = controller.songsFor(playlist, availableSongs);
        final missingCount = playlist.songIds.length - songs.length;
        return AuralisRouteScaffold(
          appBar: AppBar(
            title: Text(playlist.name),
            actions: [
              IconButton(
                tooltip: _editing ? 'Done editing' : 'Edit playlist',
                onPressed: () => setState(() => _editing = !_editing),
                icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
              ),
            ],
          ),
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
                      trailing: _editing
                          ? IconButton(
                              tooltip: 'Remove from playlist',
                              onPressed: () => controller.removeSong(playlist.id, song.id),
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                            )
                          : null,
                      onTap: () => widget.onSongSelected == null
                          ? controller.playerController.playSong(song, songs)
                          : widget.onSongSelected!(song, songs),
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
    final searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final query = searchController.text.trim().toLowerCase();
          final candidates = availableSongs
              .where((song) => !playlist.songIds.contains(song.id))
              .where((song) => query.isEmpty ||
                  song.title.toLowerCase().contains(query) ||
                  song.artist.toLowerCase().contains(query) ||
                  song.album.toLowerCase().contains(query))
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search songs',
                      ),
                    ),
                  ),
                  Expanded(
                    child: candidates.isEmpty
                        ? const Center(child: Text('No matching songs available'))
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
    searchController.dispose();
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
    return AuralisRouteScaffold(
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
  const SettingsScreen({
    required this.statistics,
    required this.sleepTimer,
    required this.themeMode,
    this.onThemeModeChanged,
    super.key,
  });

  final StatisticsController statistics;
  final SleepTimerController sleepTimer;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: Text(themeMode == ThemeMode.dark ? 'Dark theme' : 'Light theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {themeMode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light},
              onSelectionChanged: (selection) => onThemeModeChanged?.call(selection.first),
            ),
          ),
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
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.insights_rounded),
          title: const Text('Statistics'),
          subtitle: const Text('Listening activity and top music'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StatisticsScreen(controller: statistics),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: sleepTimer,
          builder: (context, _) => ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Sleep timer'),
            subtitle: Text(_sleepTimerLabel(sleepTimer)),
            onTap: () => showSleepTimerSheet(context, sleepTimer),
          ),
        ),
      ],
    );
  }
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({required this.controller, super.key});

  final StatisticsController controller;

  @override
  Widget build(BuildContext context) {
    return AuralisRouteScaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.entries.isEmpty) {
            return const Center(child: Text('Play music to build your statistics.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('Overview', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.play_circle_outline_rounded),
                  title: Text('${controller.songsPlayed} plays'),
                  subtitle: Text('Listening time: ${_formatDuration(controller.listeningTime)}'),
                ),
              ),
              const SizedBox(height: 24),
              Text('Top artists', style: Theme.of(context).textTheme.titleLarge),
              ..._statCards(
                context,
                _sortedCounts(controller.topArtists),
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),
              Text('Top genres', style: Theme.of(context).textTheme.titleLarge),
              ..._statCards(
                context,
                _sortedCounts(controller.topGenres),
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 16),
              Text('Most played songs', style: Theme.of(context).textTheme.titleLarge),
              ...controller.mostPlayed.map(
                (entry) => Card(
                  child: ListTile(
                    leading: SongArtwork(song: entry.song, size: 48),
                    title: Text(entry.song.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.song.artist),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: controller.mostPlayed.first.playCount == 0
                              ? 0
                              : entry.playCount / controller.mostPlayed.first.playCount,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                    trailing: Text('${entry.playCount}'),
                  ),
                ),
              ),
              if (controller.errorMessage != null)
                Text(
                  controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          );
        },
      ),
    );
  }
}

List<Widget> _statCards(
  BuildContext context,
  List<MapEntry<String, int>> entries, {
  required IconData icon,
}) {
  final maximum = entries.isEmpty ? 1 : entries.first.value;
  return entries
      .map(
        (entry) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(icon)),
            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: entry.value / maximum,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            trailing: Text('${entry.value}'),
          ),
        ),
      )
      .toList(growable: false);
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({required this.controller, super.key});

  final StatisticsController controller;

  @override
  Widget build(BuildContext context) {
    return AuralisRouteScaffold(
      appBar: AppBar(title: const Text('Recently played')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final entries = controller.recentlyPlayed;
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No listening history',
              message: 'Songs you play will appear here.',
              actionLabel: 'Back',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final scope = AuralisPlayerScope.maybeOf(context);
              return RealSongCard(
                song: entry.song,
                favorites: scope?.favorites,
                onTap: scope == null
                    ? null
                    : () => scope.controller.playSong(entry.song, [entry.song]),
              );
            },
          );
        },
      ),
    );
  }
}

class SleepTimerButton extends StatelessWidget {
  const SleepTimerButton({required this.controller, super.key});

  final SleepTimerController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => OutlinedButton.icon(
        onPressed: () => showSleepTimerSheet(context, controller),
        icon: const Icon(Icons.bedtime_outlined),
        label: Text(_sleepTimerLabel(controller)),
      ),
    );
  }
}

Future<void> showSleepTimerSheet(
  BuildContext context,
  SleepTimerController controller,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
          const ListTile(
            title: Text('Sleep timer'),
            subtitle: Text('Stop playback automatically'),
          ),
          for (final option in <({String label, Duration duration})>[
            (label: '15 minutes', duration: Duration(minutes: 15)),
            (label: '30 minutes', duration: Duration(minutes: 30)),
            (label: '45 minutes', duration: Duration(minutes: 45)),
            (label: '60 minutes', duration: Duration(minutes: 60)),
          ])
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(option.label),
              onTap: () {
                controller.start(option.duration);
                Navigator.pop(sheetContext);
              },
            ),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('At end of song'),
            onTap: () {
              controller.startAtEndOfSong();
              Navigator.pop(sheetContext);
            },
          ),
          if (controller.isActive)
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Cancel timer'),
              onTap: () {
                controller.cancel();
                Navigator.pop(sheetContext);
              },
            ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _sleepTimerLabel(SleepTimerController controller) {
  if (!controller.isActive) return 'Sleep timer: Off';
  if (controller.mode == SleepTimerMode.endOfSong) return 'Sleep timer: End of song';
  return 'Sleep timer: ${_formatDuration(controller.remaining ?? Duration.zero)}';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

List<MapEntry<String, int>> _sortedCounts(Map<String, int> counts) {
  return counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    required this.controller,
    required this.favorites,
    required this.sleepTimer,
    required this.availableSongs,
    super.key,
  });

  final PlayerController controller;
  final FavoritesController favorites;
  final SleepTimerController sleepTimer;
  final List<Song> availableSongs;

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
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Now playing'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
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
          body: Stack(
            children: [
              Positioned.fill(child: _PlayerBackdrop(song: song)),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
                child: Column(
                  children: [
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SongArtwork(song: song, size: 290),
                  ),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    song.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    song.artist,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    song.album,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
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
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: maxDuration.inMilliseconds.toDouble(),
                  onChanged: controller.status == PlayerStatus.loading
                      ? null
                      : (value) => controller.seek(
                            Duration(milliseconds: value.round()),
                          ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(controller.position), style: const TextStyle(color: Colors.white70)),
                    Text(_formatDuration(controller.duration), style: const TextStyle(color: Colors.white70)),
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
                const SizedBox(height: 8),
                SleepTimerButton(controller: sleepTimer),
                const SizedBox(height: 20),
                Card(
                  color: Colors.black.withValues(alpha: 0.30),
                  shadowColor: Colors.black.withValues(alpha: 0.20),
                  child: ExpansionTile(
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Artist'),
                    subtitle: Text(song.artist, style: const TextStyle(color: Colors.white70)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        child: Text(
                          '${availableSongs.where((item) => item.artist.toLowerCase() == song.artist.toLowerCase()).length} songs in your library',
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  color: Colors.black.withValues(alpha: 0.30),
                  shadowColor: Colors.black.withValues(alpha: 0.20),
                  child: ExpansionTile(
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    leading: const Icon(Icons.lyrics_outlined),
                    title: const Text('Lyrics'),
                    subtitle: const Text('Lyrics unavailable', style: TextStyle(color: Colors.white70)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        child: Text(
                          'Lyrics are not available for this local track yet.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 34, sigmaY: 34),
          child: Opacity(
            opacity: 0.78,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SongArtwork(song: song, size: MediaQuery.sizeOf(context).height),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.24),
                Colors.black.withValues(alpha: 0.68),
                Colors.black.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
      ],
    );
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
    return RepaintBoundary(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: SongArtwork(song: song, size: 52),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${song.artist} · ${song.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (favorites != null)
              FavoriteButton(song: song, favorites: favorites!),
            Text(song.durationLabel),
          ],
        ),
        onTap: onTap,
      ),
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

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -250) onTap();
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        elevation: 4,
        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ListTile(
          onTap: onTap,
          leading: SongArtwork(song: song, size: 44),
          title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            song.artist,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
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
      ),
    );
  }
}

class AuralisCard extends StatelessWidget {
  const AuralisCard({required this.child, this.padding = const EdgeInsets.all(16), super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.actionLabel, this.onAction, super.key});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
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
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
