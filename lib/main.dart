import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'models/song.dart';
import 'services/audio_handler.dart';
import 'services/player_controller.dart';
import 'services/music_scanner.dart';

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
  runApp(AuralisApp(playbackGateway: handler));
}

class AuralisApp extends StatelessWidget {
  const AuralisApp({required this.playbackGateway, super.key});

  final PlaybackGateway playbackGateway;

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
      home: AuralisShell(playbackGateway: playbackGateway),
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
  const AuralisShell({required this.playbackGateway, super.key});

  final PlaybackGateway playbackGateway;

  @override
  State<AuralisShell> createState() => _AuralisShellState();
}

class _AuralisShellState extends State<AuralisShell> {
  int _selectedIndex = 0;
  late final PlayerController _playerController;

  static const _titles = ['Good evening', 'Library', 'Playlists', 'Settings'];

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController(gateway: widget.playbackGateway);
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  void _openPlayer() {
    if (_playerController.currentSong == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(controller: _playerController),
      ),
    );
  }

  Future<void> _playSong(Song song, List<Song> songs) {
    return _playerController.playSong(song, songs);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenPlayer: _openPlayer),
      LibraryScreen(onSongSelected: _playSong),
      const PlaylistsScreen(),
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
  const HomeScreen({required this.onOpenPlayer, super.key});

  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return ListView(
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
        const SectionHeader(title: 'Recently played', actionLabel: 'See all'),
        const SizedBox(height: 12),
        SongCard(song: mockSongs[0], onTap: onOpenPlayer),
        SongCard(song: mockSongs[1], onTap: onOpenPlayer),
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
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({this.scanner, this.onSongSelected, super.key});

  final MusicScanner? scanner;
  final Future<void> Function(Song song, List<Song> songs)? onSongSelected;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final MusicScanner _scanner;
  MusicScanResult? _result;
  bool _isLoading = true;

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
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const TextField(
          decoration: InputDecoration(
            hintText: 'Search songs, artists or albums',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Songs', 'Artists', 'Albums', 'Genres']
              .map((label) => FilterChip(
                    label: Text(label),
                    selected: label == 'Songs',
                    onSelected: (_) {},
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.songs.length} songs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...result.songs.map(
              (song) => RealSongCard(
                song: song,
                onTap: widget.onSongSelected == null
                    ? null
                    : () => widget.onSongSelected!(song, result.songs),
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

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your playlists', style: Theme.of(context).textTheme.titleLarge),
            FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const EmptyState(
          icon: Icons.queue_music_rounded,
          title: 'No playlists yet',
          message: 'Create a playlist to keep your favorite moods together.',
          actionLabel: 'Create playlist',
        ),
      ],
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
  const PlayerScreen({required this.controller, super.key});

  final PlayerController controller;

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
          appBar: AppBar(title: const Text('Now playing'), centerTitle: true),
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
  const RealSongCard({required this.song, this.onTap, super.key});

  final Song song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: SongArtwork(song: song, size: 52),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${song.artist} · ${song.album}'),
      trailing: Text(song.durationLabel),
      onTap: onTap,
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
    required this.onTap,
    super.key,
  });

  final PlayerController controller;
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
        trailing: IconButton(
          onPressed: controller.togglePlayPause,
          tooltip: controller.isPlaying ? 'Pause' : 'Play',
          icon: Icon(
            controller.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
          ),
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
