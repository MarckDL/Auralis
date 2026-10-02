import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/models/playlist.dart';
import 'package:auralis/models/song.dart';
import 'package:auralis/services/audio_handler.dart';
import 'package:auralis/services/player_controller.dart';
import 'package:auralis/services/playlists_controller.dart';
import 'package:auralis/services/playlists_repository.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('auralis_playlists_test_');
    file = File('${directory.path}/playlists.json');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  PlaylistsRepository repository() =>
      PlaylistsRepository(fileProvider: () async => file);

  test('repository returns empty data for a missing or corrupt file', () async {
    expect(await repository().loadPlaylists(), isEmpty);
    await file.writeAsString('{invalid');
    expect(await repository().loadPlaylists(), isEmpty);
  });

  test('repository saves playlists and removes duplicate IDs', () async {
    final now = DateTime(2026);
    await repository().savePlaylists([
      Playlist(
        id: 'p1',
        name: 'Road trip',
        songIds: const ['a', 'a', 'b'],
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final playlists = await repository().loadPlaylists();

    expect(playlists.single.songIds, ['a', 'b']);
    expect(jsonDecode(await file.readAsString())['version'], 1);
  });

  test('controller performs playlist CRUD and preserves order', () async {
    final player = PlayerController(gateway: FakePlaybackGateway());
    final controller = PlaylistsController(
      playerController: player,
      repository: repository(),
    );
    await controller.load();
    await controller.createPlaylist('  Road trip  ');
    final playlist = controller.playlists.single;
    expect(playlist.name, 'Road trip');

    await controller.addSong(playlist.id, songA);
    await controller.addSong(playlist.id, songB);
    await controller.addSong(playlist.id, songA);
    expect(controller.findById(playlist.id)!.songIds, ['a', 'b']);

    await controller.reorderSongs(playlist.id, 1, 0);
    expect(controller.findById(playlist.id)!.songIds, ['b', 'a']);
    await controller.removeSong(playlist.id, 'b');
    expect(controller.findById(playlist.id)!.songIds, ['a']);

    await controller.renamePlaylist(playlist.id, 'Updated');
    expect(controller.findById(playlist.id)!.name, 'Updated');
    await controller.deletePlaylist(playlist.id);
    expect(controller.playlists, isEmpty);
    controller.dispose();
    player.dispose();
  });

  test('controller ignores missing songs and starts available playlist songs', () async {
    final gateway = FakePlaybackGateway();
    final player = PlayerController(gateway: gateway);
    final controller = PlaylistsController(
      playerController: player,
      repository: repository(),
    );
    await controller.load();
    await controller.createPlaylist('Available');
    final playlist = controller.playlists.single;
    await controller.addSong(playlist.id, songA);
    await controller.addSong(playlist.id, songB);

    final updatedPlaylist = controller.findById(playlist.id)!;
    expect(
      controller.songsFor(updatedPlaylist, const [songB]).map((song) => song.id),
      ['b'],
    );
    await controller.playPlaylist(playlist.id, const [songB]);
    expect(gateway.lastQueue.map((song) => song.id), ['b']);
    expect(gateway.lastInitialIndex, 0);
    controller.dispose();
    player.dispose();
  });

  test('controller rolls back when persistence fails', () async {
    final player = PlayerController(gateway: FakePlaybackGateway());
    final controller = PlaylistsController(
      playerController: player,
      repository: PlaylistsRepository(
        fileProvider: () async => throw StateError('storage unavailable'),
      ),
    );
    await controller.createPlaylist('Temporary');

    expect(controller.playlists, isEmpty);
    expect(controller.status, PlaylistsStatus.error);
    expect(controller.errorMessage, contains('storage unavailable'));
    controller.dispose();
    player.dispose();
  });
}

const songA = Song(
  id: 'a', title: 'Song A', artist: 'Artist', album: 'Album',
  duration: Duration(minutes: 3), path: '/music/a.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);
const songB = Song(
  id: 'b', title: 'Song B', artist: 'Artist', album: 'Album',
  duration: Duration(minutes: 4), path: '/music/b.mp3', format: 'mp3',
  mimeType: 'audio/mpeg',
);

class FakePlaybackGateway implements PlaybackGateway {
  final _playback = StreamController<PlaybackState>.broadcast();
  final _media = StreamController<MediaItem?>.broadcast();
  final _queue = StreamController<List<MediaItem>>.broadcast();
  List<Song> lastQueue = const [];
  int lastInitialIndex = -1;
  bool playing = false;

  @override Stream<PlaybackState> get playbackStateStream => _playback.stream;
  @override Stream<MediaItem?> get mediaItemStream => _media.stream;
  @override Stream<List<MediaItem>> get queueStream => _queue.stream;

  @override
  Future<void> setQueue(List<Song> songs, int initialIndex) async {
    lastQueue = songs;
    lastInitialIndex = initialIndex;
    _media.add(MediaItem(id: songs[initialIndex].id, title: songs[initialIndex].title));
    _state(AudioProcessingState.ready);
  }

  @override Future<void> play() async { playing = true; _state(AudioProcessingState.ready); }
  @override Future<void> pause() async { playing = false; _state(AudioProcessingState.ready); }
  @override Future<void> seek(Duration position) async {}
  @override Future<void> skipToNext() async {}
  @override Future<void> skipToPrevious() async {}
  @override Future<void> stop() async {}
  @override Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {}
  @override Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {}

  void _state(AudioProcessingState processingState) {
    _playback.add(PlaybackState(
      processingState: processingState,
      playing: playing,
      queueIndex: 0,
    ));
  }
}
