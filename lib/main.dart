import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/song.dart';
import 'online_screen.dart';
import 'models/playlist.dart';
import 'services/audio_handler.dart';
import 'services/favorites_controller.dart';
import 'services/history_controller.dart';
import 'services/player_controller.dart';
import 'services/music_scanner.dart';
import 'services/music_catalog.dart';
import 'services/mysic_controller.dart';
import 'services/playlists_controller.dart';
import 'services/auralis_database.dart';
import 'services/sleep_timer_controller.dart';
import 'services/statistics_controller.dart';
import 'services/waveform_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final handler = await AudioService.init(
    builder: AuralisAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.auralis.auralis.playback',
      androidNotificationChannelName: 'Mysic Playback',
      androidNotificationChannelDescription: 'Controls for Mysic playback',
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
      title: 'Mysic',
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
    scaffoldBackgroundColor: isLight
        ? const Color(0xFFF5F6F8)
        : const Color(0xFF101018),
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
      backgroundColor: isLight
          ? const Color(0xFF171719)
          : const Color(0xFF171722),
      height: 68,
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: isLight ? Colors.white : scheme.onSurface),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(
          color: isLight ? Colors.white70 : scheme.onSurfaceVariant,
        ),
      ),
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
  bool _isOnline = false;
  late final MysicController _mysicController;
  late final PlayerController _playerController;
  late final FavoritesController _favoritesController;
  late final PlaylistsController _playlistsController;
  late final StatisticsController _statisticsController;
  late final SleepTimerController _sleepTimerController;
  late final WaveformService _waveformService;
  List<Song> _availableSongs = const [];
  bool _libraryCacheLoaded = false;
  String _librarySearchQuery = '';
  bool _playerOpen = false;
  late List<Widget> _pages;

  static const _titles = ['Home', 'Library', 'Playlists', 'Settings'];

  @override
  void initState() {
    super.initState();
    _mysicController = MysicController();
    _statisticsController = StatisticsController(
      repository: widget.database?.historyStore,
    );
    _waveformService = WaveformService();
    _playerController = PlayerController(
      gateway: widget.playbackGateway,
      onSongStarted: (song) => song.isRemote
          ? Future<void>.value()
          : _statisticsController.recordSongStarted(song),
      onPositionChanged: (song, position, playing) => song.isRemote
          ? Future<void>.value()
          : _statisticsController.recordPosition(song, position, playing),
      onSeek: (song, position) {
        if (!song.isRemote) _statisticsController.resetPosition(song, position);
      },
      onPlaybackCompleted: () async =>
          _sleepTimerController.handleSongCompleted(),
      onQueuePositionChanged: _waveformService.prefetch,
    );
    _sleepTimerController = SleepTimerController(
      playerController: _playerController,
    );
    _favoritesController = FavoritesController(
      repository: widget.database?.favoritesStore,
    );
    _playlistsController = PlaylistsController(
      playerController: _playerController,
      repository: widget.database?.playlistsStore,
    );
    _pages = _buildPages();
    unawaited(_favoritesController.load());
    unawaited(_playlistsController.load());
    unawaited(_statisticsController.load());
    unawaited(_loadCachedSongs());
    unawaited(_mysicController.initialize());
  }

  @override
  void didUpdateWidget(covariant AuralisShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode ||
        oldWidget.onThemeModeChanged != widget.onThemeModeChanged) {
      _pages = _buildPages();
    }
  }

  Future<void> _loadCachedSongs() async {
    final database = widget.database;
    if (database == null) {
      if (mounted) setState(() => _libraryCacheLoaded = true);
      return;
    }
    final songs = await database.loadSongs();
    if (!mounted) return;
    setState(() {
      _availableSongs = songs;
      _libraryCacheLoaded = true;
      _pages = _buildPages();
    });
    unawaited(_waveformService.prune(songs));
  }

  @override
  void dispose() {
    _playerController.dispose();
    _statisticsController.dispose();
    _sleepTimerController.dispose();
    _favoritesController.dispose();
    _playlistsController.dispose();
    _mysicController.dispose();
    if (widget.database != null) unawaited(widget.database!.close());
    super.dispose();
  }

  void _openPlayer() {
    if (_playerController.currentSong == null) return;
    if (_playerOpen) return;
    _playerOpen = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PlayerScreen(
              controller: _playerController,
              favorites: _favoritesController,
              availableSongs: _availableSongs,
              waveformService: _waveformService,
              mysic: _mysicController,
            ),
          ),
        )
        .whenComplete(() => _playerOpen = false);
  }

  Future<void> _playSong(Song song, List<Song> songs) async {
    await _requestNotificationPermission();
    await _playerController.playSong(song, songs);
    if (mounted && !_playerOpen) _openPlayer();
  }

  Future<void> _logoutOnline() async {
    if (_playerController.currentSong?.isRemote ?? false) {
      await _playerController.stop();
    }
    await _mysicController.logout();
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
      _pages = _buildPages();
    });
  }

  void _clearLibrarySearch() {
    if (_librarySearchQuery.isEmpty) return;
    setState(() {
      _librarySearchQuery = '';
      _pages = _buildPages();
    });
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
      builder: (_) =>
          const PlaylistNameDialog(initialName: '', title: 'New playlist'),
    );
    if (name != null) await _playlistsController.createPlaylist(name);
  }

  List<Widget> _buildPages() {
    return [
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
        initialSongs: _availableSongs,
        initialSongsReady: _libraryCacheLoaded,
        initialSearchQuery: _librarySearchQuery,
        onSearchCleared: _clearLibrarySearch,
        onSongsChanged: (songs) {
          if (mounted) {
            setState(() {
              _availableSongs = songs;
              _pages = _buildPages();
            });
          }
          unawaited(_waveformService.prune(songs));
          if (widget.database != null) {
            unawaited(widget.database!.upsertSongs(songs));
          }
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
        isOnline: _isOnline,
        onModeChanged: (online) => setState(() {
          _isOnline = online;
          _pages = _buildPages();
        }),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AuralisPlayerScope(
      controller: _playerController,
      favorites: _favoritesController,
      onOpenPlayer: _openPlayer,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isOnline
                ? 'Mysic'
                : _selectedIndex == 0
                ? _greeting()
                : _titles[_selectedIndex],
          ),
          actions: _isOnline
              ? [
                  IconButton(
                    tooltip: 'Configuración',
                    onPressed: () => setState(() {
                      _isOnline = false;
                      _selectedIndex = 3;
                      _pages = _buildPages();
                    }),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ]
              : null,
        ),
        body: SafeArea(
          top: true,
          bottom: false,
          child: IndexedStack(
            index: _isOnline ? 1 : 0,
            children: [
              IndexedStack(index: _selectedIndex, children: _pages),
              MysicOnlineScreen(
                controller: _mysicController,
                onPlaySong: _playSong,
                onLogout: _logoutOnline,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          left: false,
          right: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerMiniBar(
                controller: _playerController,
                favorites: _favoritesController,
                onTap: _openPlayer,
              ),
              if (!_isOnline)
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
    final theme = Theme.of(context);
    final catalog = MusicCatalog(availableSongs);
    final recentSongs = history.recentlyPlayed
        .map((entry) => entry.song)
        .toList(growable: false);
    final newestSongs = [...availableSongs]
      ..sort(
        (a, b) =>
            (b.dateAdded ?? DateTime(0)).compareTo(a.dateAdded ?? DateTime(0)),
      );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        TextField(
          onSubmitted: onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search songs, artists, albums',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Icon(
              Icons.tune_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (catalog.artists.isNotEmpty) ...[
          const _HomeSectionTitle(title: 'Top artists'),
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: catalog.artists.take(8).length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final artist = catalog.artists[index];
                return _HomeArtistTile(
                  artist: artist,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistDetailScreen(
                        artist: artist.name,
                        songs: availableSongs,
                        favorites: favorites,
                        onSongSelected: onSongSelected,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (catalog.albums.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _HomeSectionTitle(title: 'New album'),
          const SizedBox(height: 10),
          _HomeFeaturedAlbum(
            album: catalog.albums.first,
            onPlay: onSongSelected == null || catalog.albums.first.songs.isEmpty
                ? null
                : () => onSongSelected!(
                    catalog.albums.first.songs.first,
                    catalog.albums.first.songs,
                  ),
          ),
        ],
        const SizedBox(height: 24),
        _HomeSectionTitle(
          title: 'Recently played',
          actionLabel: recentSongs.isNotEmpty ? 'See all' : null,
          onAction: onSeeAll,
        ),
        const SizedBox(height: 10),
        if (recentSongs.isNotEmpty)
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentSongs.take(8).length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final song = recentSongs[index];
                return _HomeSongTile(
                  song: song,
                  onTap: onSongSelected == null
                      ? null
                      : () => onSongSelected!(song, availableSongs),
                );
              },
            ),
          )
        else
          AuralisCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.history_rounded,
                color: theme.colorScheme.primary,
              ),
              title: const Text('No recent plays'),
              subtitle: const Text('Start listening to build your history.'),
            ),
          ),
        if (newestSongs.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _HomeSectionTitle(title: 'Recently added'),
          const SizedBox(height: 4),
          ...newestSongs
              .take(2)
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
        if (playlists != null &&
            onCreatePlaylist != null &&
            onOpenPlaylist != null) ...[
          const SizedBox(height: 28),
          _HomePlaylistsSection(
            controller: playlists!,
            availableSongs: availableSongs,
            onCreatePlaylist: onCreatePlaylist!,
            onOpenPlaylist: onOpenPlaylist!,
          ),
        ],
      ],
    );
  }
}

class _HomeArtistTile extends StatelessWidget {
  const _HomeArtistTile({required this.artist, required this.onTap});

  final ArtistSummary artist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final song = artist.songs.first;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            ClipOval(child: SongArtwork(song: song, size: 64)),
            const SizedBox(height: 7),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class _HomeFeaturedAlbum extends StatelessWidget {
  const _HomeFeaturedAlbum({required this.album, this.onPlay});

  final AlbumSummary album;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final song = album.songs.first;
    return SizedBox(
      height: 142,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (song.hasArtwork)
              Image.memory(
                song.artwork!,
                fit: BoxFit.cover,
                cacheWidth: 1000,
                filterQuality: FilterQuality.low,
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: onPlay,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF39277F),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _HomeSongTile extends StatelessWidget {
  const _HomeSongTile({required this.song, this.onTap});
  final Song song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 106,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SongArtwork(song: song, size: 106),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    this.scanner,
    this.favorites,
    this.initialSongs = const [],
    this.initialSongsReady = true,
    this.onSongsChanged,
    this.onSongSelected,
    this.initialSearchQuery = '',
    this.onSearchCleared,
    super.key,
  });

  final MusicScanner? scanner;
  final FavoritesController? favorites;
  final List<Song> initialSongs;
  final bool initialSongsReady;
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
    if (widget.initialSongsReady) {
      _useInitialSongsOrScan();
    }
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.initialSongsReady && widget.initialSongsReady) {
      _useInitialSongsOrScan();
    } else if (widget.initialSongsReady &&
        oldWidget.initialSongs != widget.initialSongs &&
        widget.initialSongs.isNotEmpty) {
      _showCachedSongs(widget.initialSongs);
    }
    if (oldWidget.initialSearchQuery != widget.initialSearchQuery &&
        widget.initialSearchQuery != _searchQuery) {
      _searchQuery = widget.initialSearchQuery.trim();
      _searchController.value = TextEditingValue(
        text: _searchQuery,
        selection: TextSelection.collapsed(offset: _searchQuery.length),
      );
    }
  }

  void _useInitialSongsOrScan() {
    if (widget.initialSongs.isNotEmpty) {
      _showCachedSongs(widget.initialSongs);
    } else {
      _loadLibrary();
    }
  }

  void _showCachedSongs(List<Song> songs) {
    if (!mounted) return;
    setState(() {
      _result = MusicScanResult.success(List<Song>.unmodifiable(songs));
      _isLoading = false;
    });
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
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Update library',
                  onPressed: _isLoading ? null : _loadLibrary,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (widget.favorites != null)
                  TextButton.icon(
                    onPressed: () => _openFavorites(context),
                    icon: const Icon(Icons.favorite_rounded, size: 18),
                    label: const Text('Favorites'),
                  ),
              ],
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
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Songs', 'Artists', 'Albums', 'Genres']
                .map(
                  (label) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilterChip(
                      label: Text(label),
                      selected: label == _selectedCategory,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = label),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
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
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AlphabeticalList(
              items: [...filteredSongs]
                ..sort(
                  (a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                ),
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
    return songs
        .where((song) {
          return song.title.toLowerCase().contains(query) ||
              song.artist.toLowerCase().contains(query) ||
              song.album.toLowerCase().contains(query);
        })
        .toList(growable: false);
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
            _HomeSectionTitle(
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
              SizedBox(
                height: 154,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: playlists.take(8).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final songs = controller.songsFor(playlist, availableSongs);
                    return _HomePlaylistTile(
                      playlist: playlist,
                      songs: songs,
                      onOpen: () => onOpenPlaylist(playlist),
                      onPlay: songs.isEmpty
                          ? null
                          : () => controller.playPlaylist(
                              playlist.id,
                              availableSongs,
                            ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomePlaylistTile extends StatelessWidget {
  const _HomePlaylistTile({
    required this.playlist,
    required this.songs,
    required this.onOpen,
    this.onPlay,
  });

  final Playlist playlist;
  final List<Song> songs;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 106,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PlaylistArtwork(songs: songs, size: 106),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: IconButton.filled(
                    onPressed: onPlay,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF39277F),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${songs.length} songs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class PlaylistArtwork extends StatelessWidget {
  const PlaylistArtwork({required this.songs, required this.size, super.key});

  final List<Song> songs;
  final double size;

  @override
  Widget build(BuildContext context) {
    final song = songs.isEmpty ? null : songs.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size > 70 ? 20 : 14),
      child: SizedBox.square(
        dimension: size,
        child: song == null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  AlbumArtwork(color: const Color(0xFF7657E8), size: size),
                  Center(
                    child: Icon(
                      Icons.queue_music_rounded,
                      size: size * 0.42,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : SongArtwork(song: song, size: size),
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
  String? _selectedLetter;

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
    }.toList()..sort();
    return SizedBox(
      height: 500,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.items.length,
              itemBuilder: (_, index) =>
                  widget.itemBuilder(widget.items[index]),
            ),
          ),
          SizedBox(
            width: 24,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemExtent: 24,
              itemCount: initials.length,
              itemBuilder: (context, letterIndex) {
                final letter = initials[letterIndex];
                final index = widget.items.indexWhere(
                  (item) => _initial(widget.labelFor(item)) == letter,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _selectedLetter = letter);
                    _scrollController.animateTo(
                      (index * 76)
                          .clamp(0, _scrollController.position.maxScrollExtent)
                          .toDouble(),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedLetter == letter
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      letter,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _selectedLetter == letter
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
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
        items: [
          ...catalog.artists,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
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
                  subtitle: Text(
                    '${album.artist} · ${album.songs.length} songs',
                  ),
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
                leading: const CircleAvatar(
                  child: Icon(Icons.category_rounded),
                ),
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

class ArtistDetailScreen extends StatefulWidget {
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
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final artistSongs = MusicCatalog(widget.songs)
        .songsForArtist(widget.artist);
    final albums = MusicCatalog(artistSongs).albums;
    return AuralisRouteScaffold(
      appBar: AppBar(title: Text(widget.artist)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            '${artistSongs.length} songs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: artistSongs.isEmpty || widget.onSongSelected == null
                ? null
                : () => widget.onSongSelected!(artistSongs.first, artistSongs),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play all'),
          ),
          const SizedBox(height: 20),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Albums')),
              ButtonSegment(value: 1, label: Text('Songs')),
            ],
            selected: {_section},
            onSelectionChanged: (values) =>
                setState(() => _section = values.first),
          ),
          const SizedBox(height: 12),
          if (_section == 0)
            if (albums.isEmpty)
              const ListTile(title: Text('No albums'))
            else
              ...albums.map(
                (album) => ListTile(
                  leading: SongArtwork(song: album.songs.first, size: 48),
                  title: Text(album.name),
                  subtitle: Text(
                    '${album.songs.length} songs · ${_durationLabel(album.totalDuration)}',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AlbumDetailScreen(
                        albumId: album.id,
                        songs: artistSongs,
                        favorites: widget.favorites,
                        onSongSelected: widget.onSongSelected,
                      ),
                    ),
                  ),
                ),
              )
          else
            ...artistSongs.map(
              (song) => RealSongCard(
                song: song,
                favorites: widget.favorites,
                onTap: widget.onSongSelected == null
                    ? null
                    : () => widget.onSongSelected!(song, artistSongs),
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
          if (album.songs.isNotEmpty)
            SongArtwork(song: album.songs.first, size: 180),
          const SizedBox(height: 16),
          Text(album.name, style: Theme.of(context).textTheme.headlineSmall),
          Text(album.artist),
          Text(
            '${album.songs.length} songs · ${_durationLabel(album.totalDuration)}',
          ),
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
          Text(
            '${genreSongs.length} songs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                const Spacer(),
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
                message:
                    'Create a playlist to keep your favorite moods together.',
                actionLabel: 'Create playlist',
                onAction: () => _showPlaylistDialog(context),
              )
            else
              ...controller.playlists.map((playlist) {
                final songs = controller.songsFor(playlist, availableSongs);
                return Card(
                  child: ListTile(
                    leading: PlaylistArtwork(songs: songs, size: 56),
                    title: Text(playlist.name),
                    subtitle: Text('${songs.length} available songs'),
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
                        if (value == 'edit') {
                          _showPlaylistDialog(context, playlist);
                        }
                        if (value == 'delete') {
                          _confirmDelete(context, playlist);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit name')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _showPlaylistDialog(
    BuildContext context, [
    Playlist? playlist,
  ]) async {
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
        content: const Text(
          'This playlist and its song order will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
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
          return const AuralisRouteScaffold(
            body: Center(child: Text('Playlist not found')),
          );
        }
        final songs = controller.songsFor(playlist, availableSongs);
        final missingCount = playlist.songIds.length - songs.length;
        return AuralisRouteScaffold(
          appBar: AppBar(
            title: const SizedBox.shrink(),
            actions: [
              IconButton(
                tooltip: 'Search and add songs',
                onPressed: () => _showSongSelector(context, playlist),
                icon: const Icon(Icons.search_rounded),
              ),
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        PlaylistArtwork(songs: songs, size: 104),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PLAYLIST · ${songs.length} SONGS',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      letterSpacing: 0.7,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                playlist.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                songs.isEmpty
                                    ? 'No songs yet'
                                    : '${songs.length} available · ${_playlistDuration(songs)}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: songs.isEmpty
                                ? null
                                : () => controller.playPlaylist(
                                    playlist.id,
                                    availableSongs,
                                  ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: songs.isEmpty
                                ? null
                                : () {
                                    final shuffled = List<Song>.of(songs)
                                      ..shuffle(math.Random());
                                    controller.playerController.playSong(
                                      shuffled.first,
                                      shuffled,
                                    );
                                  },
                            icon: const Icon(Icons.shuffle_rounded),
                            label: const Text('Shuffle'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (missingCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '$missingCount song(s) are not available in the current library.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: songs.isEmpty
                    ? Center(
                        child: Text(
                          playlist.songIds.isEmpty
                              ? 'Add songs to start this playlist'
                              : 'No playlist songs are available in your library',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: songs.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          final oldPlaylistIndex = playlist.songIds.indexOf(
                            songs[oldIndex].id,
                          );
                          final newPlaylistIndex = newIndex >= songs.length
                              ? playlist.songIds.length
                              : playlist.songIds.indexOf(songs[newIndex].id);
                          controller.reorderSongs(
                            playlist.id,
                            oldPlaylistIndex,
                            newPlaylistIndex,
                          );
                        },
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return ListTile(
                            key: ValueKey(song.id),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            minLeadingWidth: 30,
                            leading: SizedBox(
                              width: 30,
                              child: Center(
                                child: Text(
                                  (index + 1).toString().padLeft(2, '0'),
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${song.artist} · ${song.durationLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _editing
                                ? IconButton(
                                    tooltip: 'Remove from playlist',
                                    onPressed: () => controller.removeSong(
                                      playlist.id,
                                      song.id,
                                    ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                    ),
                                  )
                                : null,
                            onTap: () => widget.onSongSelected == null
                                ? controller.playerController.playSong(
                                    song,
                                    songs,
                                  )
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

  String _playlistDuration(List<Song> songs) {
    final totalSeconds = songs.fold<int>(
      0,
      (total, song) => total + song.duration.inSeconds,
    );
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return hours > 0 ? '$hours h $minutes min' : '$minutes min';
  }

  Future<void> _showSongSelector(
    BuildContext context,
    Playlist playlist,
  ) async {
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
              .where(
                (song) =>
                    query.isEmpty ||
                    song.title.toLowerCase().contains(query) ||
                    song.artist.toLowerCase().contains(query) ||
                    song.album.toLowerCase().contains(query),
              )
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
                        ? const Center(
                            child: Text('No matching songs available'),
                          )
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
                              for (final song in candidates.where(
                                (song) => selectedIds.contains(song.id),
                              )) {
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
                      : () =>
                            onSongSelected!(favoriteSongs.first, favoriteSongs),
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
                        : () => onSongSelected!(
                            favoriteSongs[index],
                            favoriteSongs,
                          ),
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
    required this.isOnline,
    required this.onModeChanged,
    this.onThemeModeChanged,
    super.key,
  });

  final StatisticsController statistics;
  final SleepTimerController sleepTimer;
  final ThemeMode themeMode;
  final bool isOnline;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('Biblioteca', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('En mi dispositivo')),
            ButtonSegment(value: true, label: Text('En línea')),
          ],
          selected: {isOnline},
          onSelectionChanged: (values) => onModeChanged(values.first),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: Text(
              themeMode == ThemeMode.dark ? 'Dark theme' : 'Light theme',
            ),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {
                themeMode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
              },
              onSelectionChanged: (selection) =>
                  onThemeModeChanged?.call(selection.first),
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
            return const Center(
              child: Text('Play music to build your statistics.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _StatisticsHero(controller: controller),
              const SizedBox(height: 26),
              _StatisticsSectionTitle(
                title: 'On repeat',
                caption: 'Your most played tracks',
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: math.min(controller.mostPlayed.length, 8),
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final entry = controller.mostPlayed[index];
                    return _TopSongStatCard(entry: entry, rank: index + 1);
                  },
                ),
              ),
              const SizedBox(height: 26),
              _StatisticsSectionTitle(
                title: 'Top artists',
                caption: 'Who shaped your listening',
              ),
              const SizedBox(height: 12),
              _ArtistRankingCard(
                entries: _sortedCounts(controller.topArtists).take(6).toList(),
              ),
              const SizedBox(height: 26),
              _StatisticsSectionTitle(
                title: 'Genre mix',
                caption: 'The sound of your library',
              ),
              const SizedBox(height: 12),
              _GenreMixCard(
                entries: _sortedCounts(controller.topGenres).take(5).toList(),
              ),
              if (controller.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    controller.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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

class _StatisticsSectionTitle extends StatelessWidget {
  const _StatisticsSectionTitle({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _StatisticsHero extends StatelessWidget {
  const _StatisticsHero({required this.controller});

  final StatisticsController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.4)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: scheme.onPrimary),
              const SizedBox(width: 9),
              Text(
                'Your listening',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  value: '${controller.songsPlayed}',
                  label: 'plays',
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: scheme.onPrimary.withValues(alpha: 0.25),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: _HeroMetric(
                    value: _compactListeningTime(controller.listeningTime),
                    label: 'listening time',
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: scheme.onPrimary.withValues(alpha: 0.25),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: _HeroMetric(
                    value: '${controller.entries.length}',
                    label: 'tracks',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: foreground.withValues(alpha: 0.78)),
        ),
      ],
    );
  }
}

class _TopSongStatCard extends StatelessWidget {
  const _TopSongStatCard({required this.entry, required this.rank});

  final HistoryEntry entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SongArtwork(song: entry.song, size: 136),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${entry.playCount} plays · ${entry.song.artist}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ArtistRankingCard extends StatelessWidget {
  const _ArtistRankingCard({required this.entries});

  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    final maximum = entries.isEmpty ? 1 : entries.first.value;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        child: Column(
          children: [
            for (final indexed in entries.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${indexed.$1 + 1}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            indexed.$2.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: indexed.$2.value / maximum,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${indexed.$2.value}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GenreMixCard extends StatelessWidget {
  const _GenreMixCard({required this.entries});

  final List<MapEntry<String, int>> entries;

  static const colors = [
    Color(0xFF7258C7),
    Color(0xFFFF8A65),
    Color(0xFF4DB6AC),
    Color(0xFF64B5F6),
    Color(0xFFBA68C8),
  ];

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    for (final indexed in entries.indexed)
                      Expanded(
                        flex: indexed.$2.value,
                        child: ColoredBox(
                          color: colors[indexed.$1 % colors.length],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final indexed in entries.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: colors[indexed.$1 % colors.length].withValues(
                        alpha: 0.13,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors[indexed.$1 % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${indexed.$2.key} ${total == 0 ? 0 : (indexed.$2.value * 100 / total).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                'Sleep timer',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Stop playback automatically'),
            ),
            if (controller.errorMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final option in <({String label, Duration duration})>[
              (label: '15 minutes', duration: Duration(minutes: 15)),
              (label: '30 minutes', duration: Duration(minutes: 30)),
              (label: '45 minutes', duration: Duration(minutes: 45)),
              (label: '60 minutes', duration: Duration(minutes: 60)),
            ])
              ListTile(
                leading: Icon(
                  Icons.timer_outlined,
                  color:
                      controller.mode == SleepTimerMode.duration &&
                          controller.remaining != null &&
                          controller.remaining! <= option.duration &&
                          controller.remaining! >
                              option.duration - const Duration(minutes: 1)
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(option.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _activateSleepTimer(
                  context,
                  sheetContext,
                  controller,
                  () => controller.start(option.duration),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: const Text('At end of song'),
              trailing: controller.mode == SleepTimerMode.endOfSong
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => _activateSleepTimer(
                context,
                sheetContext,
                controller,
                controller.startAtEndOfSong,
              ),
            ),
            if (controller.isActive) ...[
              const Divider(height: 20),
              ListTile(
                leading: Icon(
                  Icons.cancel_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Cancel timer'),
                onTap: () {
                  controller.cancel();
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

void _activateSleepTimer(
  BuildContext rootContext,
  BuildContext sheetContext,
  SleepTimerController controller,
  bool Function() activate,
) {
  final activated = activate();
  if (activated) {
    Navigator.pop(sheetContext);
    ScaffoldMessenger.of(rootContext)
        .showSnackBar(SnackBar(content: Text(_sleepTimerLabel(controller))));
  }
}

String _sleepTimerLabel(SleepTimerController controller) {
  if (!controller.isActive) return 'Sleep timer: Off';
  if (controller.mode == SleepTimerMode.endOfSong) {
    return 'Sleep timer: End of song';
  }
  return 'Sleep timer: ${_formatDuration(controller.remaining ?? Duration.zero)}';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String _compactListeningTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m';
  return '${duration.inSeconds}s';
}

List<MapEntry<String, int>> _sortedCounts(Map<String, int> counts) {
  return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

class _PlayerWaveform extends StatelessWidget {
  const _PlayerWaveform({
    required this.position,
    required this.duration,
    required this.color,
    this.waveform,
    this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final Color color;
  final Waveform? waveform;
  final ValueChanged<Duration>? onSeek;

  void _seek(Offset localPosition, double width) {
    if (onSeek == null || width <= 0) return;
    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    onSeek!(Duration(milliseconds: (duration.inMilliseconds * ratio).round()));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) =>
            _seek(details.localPosition, constraints.maxWidth),
        onHorizontalDragUpdate: (details) =>
            _seek(details.localPosition, constraints.maxWidth),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: CustomPaint(
            painter: _PlayerWaveformPainter(
              progress: duration.inMilliseconds == 0
                  ? 0
                  : position.inMilliseconds / duration.inMilliseconds,
              color: color,
              waveform: waveform,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerWaveformPainter extends CustomPainter {
  const _PlayerWaveformPainter({
    required this.progress,
    required this.color,
    this.waveform,
  });

  final double progress;
  final Color color;
  final Waveform? waveform;

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final inactivePaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    if (waveform == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, size.height / 2 - 2, size.width, 4),
          const Radius.circular(4),
        ),
        inactivePaint,
      );
      canvas.drawCircle(
        Offset(size.width * clampedProgress, size.height / 2),
        5,
        activePaint,
      );
      return;
    }
    const barCount = 64;
    final gap = 2.2;
    final barWidth = (size.width - (barCount - 1) * gap) / barCount;

    for (var index = 0; index < barCount; index++) {
      final x = index * (barWidth + gap);
      final actual = _actualBarHeight(index, barCount, size.height);
      final height = actual ?? 6.0;
      final top = (size.height - height) / 2;
      final paint = x + barWidth / 2 <= size.width * clampedProgress
          ? activePaint
          : inactivePaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, height),
          const Radius.circular(4),
        ),
        paint,
      );
    }

    final thumbPaint = Paint()..color = color;
    canvas.drawCircle(
      Offset(size.width * clampedProgress, size.height / 2),
      5,
      thumbPaint,
    );
  }

  double? _actualBarHeight(int index, int barCount, double canvasHeight) {
    final value = waveform;
    if (value == null || value.duration == Duration.zero) return null;
    final pixelCount = value.positionToPixel(value.duration);
    if (pixelCount <= 0) return null;
    final sample = (index * pixelCount / barCount).round();
    final minY = _normalise(
      value.getPixelMin(sample),
      canvasHeight,
      value.flags,
    );
    final maxY = _normalise(
      value.getPixelMax(sample),
      canvasHeight,
      value.flags,
    );
    return (maxY - minY).abs().clamp(6.0, canvasHeight - 4).toDouble();
  }

  double _normalise(int sample, double height, int flags) {
    if (flags == 0) {
      final y = 32768 + sample.clamp(-32768, 32767);
      return height - 1 - y * height / 65536;
    }
    final y = 128 + sample.clamp(-128, 127);
    return height - 1 - y * height / 256;
  }

  @override
  bool shouldRepaint(covariant _PlayerWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.waveform != waveform;
  }
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    required this.controller,
    required this.favorites,
    required this.availableSongs,
    required this.waveformService,
    required this.mysic,
    super.key,
  });

  final PlayerController controller;
  final FavoritesController favorites;
  final List<Song> availableSongs;
  final WaveformService waveformService;
  final MysicController mysic;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        if (song == null) {
          return const Scaffold(body: Center(child: Text('No song selected')));
        }

        final theme = Theme.of(context);
        final maxDuration = controller.duration.inMilliseconds > 0
            ? controller.duration
            : const Duration(seconds: 1);
        final position = controller.position > maxDuration
            ? maxDuration
            : controller.position;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Close player',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            title: const Text('Now Playing'),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Play queue',
                onPressed: () => _showQueue(context),
                icon: const Icon(Icons.queue_music_rounded),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final artworkSize = constraints.maxWidth - 44 > 330
                    ? 330.0
                    : constraints.maxWidth - 44;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  child: Column(
                    children: [
                      SongArtwork(song: song, size: artworkSize),
                      const SizedBox(height: 24),
                      ListenableBuilder(
                        listenable: song.isRemote ? mysic : favorites,
                        builder: (context, _) => Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip:
                                  (song.isRemote
                                      ? mysic.isFavorite(song)
                                      : favorites.isFavorite(song))
                                  ? 'Remove favorite'
                                  : 'Add favorite',
                              onPressed: () => song.isRemote
                                  ? mysic.toggleFavorite(song)
                                  : favorites.toggleFavorite(song),
                              icon: Icon(
                                (song.isRemote
                                        ? mysic.isFavorite(song)
                                        : favorites.isFavorite(song))
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color:
                                    (song.isRemote
                                        ? mysic.isFavorite(song)
                                        : favorites.isFavorite(song))
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'More options',
                              onPressed: () => _showMore(context, song),
                              icon: const Icon(Icons.more_horiz_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<Waveform?>(
                        key: ValueKey(song.id),
                        future: waveformService.load(song),
                        builder: (context, snapshot) => _PlayerWaveform(
                          position: position,
                          duration: maxDuration,
                          color: theme.colorScheme.primary,
                          waveform: snapshot.data,
                          onSeek: controller.status == PlayerStatus.loading
                              ? null
                              : controller.seek,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position)),
                          Text(_formatDuration(controller.duration)),
                        ],
                      ),
                      if (controller.status == PlayerStatus.error)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            controller.errorMessage ??
                                'Unable to play this song.',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            tooltip: 'Shuffle',
                            onPressed: controller.toggleShuffle,
                            color:
                                controller.shuffleMode ==
                                    AudioServiceShuffleMode.all
                                ? theme.colorScheme.primary
                                : null,
                            icon: const Icon(Icons.shuffle_rounded),
                          ),
                          IconButton(
                            tooltip: 'Previous',
                            onPressed: controller.previous,
                            icon: const Icon(Icons.skip_previous_rounded),
                          ),
                          FloatingActionButton(
                            heroTag: 'player-play-button',
                            onPressed: controller.status == PlayerStatus.loading
                                ? null
                                : controller.togglePlayPause,
                            child: controller.status == PlayerStatus.loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    controller.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 30,
                                  ),
                          ),
                          IconButton(
                            tooltip: 'Next',
                            onPressed: controller.next,
                            icon: const Icon(Icons.skip_next_rounded),
                          ),
                          IconButton(
                            tooltip: 'Repeat',
                            onPressed: controller.cycleRepeatMode,
                            color:
                                controller.repeatMode ==
                                    AudioServiceRepeatMode.none
                                ? null
                                : theme.colorScheme.primary,
                            icon: Icon(
                              controller.repeatMode ==
                                      AudioServiceRepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _PlayerInfoTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Artist',
                        subtitle: song.artist,
                        child: Text(
                          '${availableSongs.where((item) => item.artist.toLowerCase() == song.artist.toLowerCase()).length} songs in your library',
                        ),
                      ),
                      _PlayerInfoTile(
                        icon: Icons.lyrics_outlined,
                        title: 'Lyrics',
                        subtitle: 'Lyrics unavailable',
                        child: const Text(
                          'Lyrics are not available for this local track yet.',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showMore(BuildContext context, Song song) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.album_outlined),
              title: Text(song.album),
              subtitle: Text(song.artist),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('File information'),
              subtitle: Text(song.format.toUpperCase()),
            ),
          ],
        ),
      ),
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

class _PlayerInfoTile extends StatelessWidget {
  const _PlayerInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: child,
          ),
        ],
      ),
    );
  }
}

// Kept temporarily while the new player is validated on physical devices.
// ignore: unused_element
class _LegacyPlayerScreen extends StatelessWidget {
  const _LegacyPlayerScreen({
    required this.controller,
    required this.favorites,
    required this.sleepTimer,
    required this.availableSongs,
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
          return const Scaffold(body: Center(child: Text('No song selected')));
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        song.artist,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
                          controller.errorMessage ??
                              'Unable to play this song.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.28,
                        ),
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
                        Text(
                          _formatDuration(controller.position),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          _formatDuration(controller.duration),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: controller.toggleShuffle,
                          tooltip: 'Shuffle',
                          color:
                              controller.shuffleMode ==
                                  AudioServiceShuffleMode.all
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                          color:
                              controller.repeatMode ==
                                  AudioServiceRepeatMode.none
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
                        subtitle: Text(
                          song.artist,
                          style: const TextStyle(color: Colors.white70),
                        ),
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
                        subtitle: const Text(
                          'Lyrics unavailable',
                          style: TextStyle(color: Colors.white70),
                        ),
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
              child: SongArtwork(
                song: song,
                size: MediaQuery.sizeOf(context).height,
              ),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        leading: SongArtwork(song: song, size: 58),
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: favorites == null
            ? null
            : FavoriteButton(song: song, favorites: favorites!),
        onTap: onTap,
      ),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    required this.song,
    required this.favorites,
    super.key,
  });

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
    if (song.artworkUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size > 70 ? 18 : 12),
        child: Image.network(
          song.artworkUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackArtwork(),
        ),
      );
    }
    if (song.hasArtwork) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size > 70 ? 18 : 12),
        child: Image.memory(
          song.artwork!,
          width: size,
          height: size,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(64, 1024),
          cacheHeight: (size * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(64, 1024),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => _fallbackArtwork(),
        ),
      );
    }
    return _fallbackArtwork();
  }

  Widget _fallbackArtwork() {
    final color =
        Colors.primaries[song.title.hashCode.abs() % Colors.primaries.length];
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
        shadowColor: Theme.of(context).colorScheme.primary
            .withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ListTile(
          onTap: onTap,
          leading: SongArtwork(song: song, size: 44),
          title: Text(
            song.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            song.artist,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!song.isRemote)
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
  const AuralisCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

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
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

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
