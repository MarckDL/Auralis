import 'package:flutter/foundation.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import 'player_controller.dart';
import 'playlists_repository.dart';

enum PlaylistsStatus { idle, loading, ready, error }

class PlaylistsController extends ChangeNotifier {
  PlaylistsController({
    required this.playerController,
    PlaylistsStore? repository,
  }) : _repository = repository ?? PlaylistsRepository();

  final PlayerController playerController;
  final PlaylistsStore _repository;
  List<Playlist> _playlists = const [];
  PlaylistsStatus _status = PlaylistsStatus.idle;
  String? _errorMessage;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  PlaylistsStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Playlist? findById(String id) {
    for (final playlist in _playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  List<Song> songsFor(Playlist playlist, List<Song> availableSongs) {
    final byId = {for (final song in availableSongs) song.id: song};
    return playlist.songIds
        .map((id) => byId[id])
        .whereType<Song>()
        .toList(growable: false);
  }

  Future<void> load() async {
    _status = PlaylistsStatus.loading;
    _errorMessage = null;
    notifyListeners();
    _playlists = await _repository.loadPlaylists();
    _status = PlaylistsStatus.ready;
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _setError('Playlist name cannot be empty.');
      return;
    }
    final now = DateTime.now();
    final playlist = Playlist(
      id: '${now.microsecondsSinceEpoch}',
      name: trimmedName,
      songIds: const [],
      createdAt: now,
      updatedAt: now,
    );
    await _update([..._playlists, playlist]);
  }

  Future<void> renamePlaylist(String id, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _setError('Playlist name cannot be empty.');
      return;
    }
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index == -1) return;
    final updated = _playlists[index].copyWith(
      name: trimmedName,
      updatedAt: DateTime.now(),
    );
    final next = List<Playlist>.of(_playlists)..[index] = updated;
    await _update(next);
  }

  Future<void> deletePlaylist(String id) async {
    await _update(_playlists.where((playlist) => playlist.id != id).toList());
  }

  Future<void> addSong(String playlistId, Song song) async {
    final playlist = findById(playlistId);
    if (playlist == null || playlist.songIds.contains(song.id)) return;
    await _replacePlaylist(
      playlist.copyWith(
        songIds: [...playlist.songIds, song.id],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeSong(String playlistId, String songId) async {
    final playlist = findById(playlistId);
    if (playlist == null) return;
    await _replacePlaylist(
      playlist.copyWith(
        songIds: playlist.songIds.where((id) => id != songId).toList(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> reorderSongs(String playlistId, int oldIndex, int newIndex) async {
    final playlist = findById(playlistId);
    if (playlist == null || oldIndex < 0 || oldIndex >= playlist.songIds.length) return;
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) targetIndex--;
    if (targetIndex < 0 || targetIndex >= playlist.songIds.length) return;
    final songIds = List<String>.of(playlist.songIds);
    final songId = songIds.removeAt(oldIndex);
    songIds.insert(targetIndex, songId);
    await _replacePlaylist(
      playlist.copyWith(songIds: songIds, updatedAt: DateTime.now()),
    );
  }

  Future<void> playPlaylist(String playlistId, List<Song> availableSongs) async {
    final playlist = findById(playlistId);
    if (playlist == null) return;
    final songs = songsFor(playlist, availableSongs);
    if (songs.isEmpty) {
      _setError('This playlist has no available songs.');
      return;
    }
    await playerController.playSong(songs.first, songs);
  }

  Future<void> _replacePlaylist(Playlist playlist) async {
    final index = _playlists.indexWhere((item) => item.id == playlist.id);
    if (index == -1) return;
    final next = List<Playlist>.of(_playlists)..[index] = playlist;
    await _update(next);
  }

  Future<void> _update(List<Playlist> next) async {
    final previous = _playlists;
    _playlists = List.unmodifiable(next);
    _status = PlaylistsStatus.ready;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.savePlaylists(_playlists);
    } catch (error) {
      _playlists = previous;
      _setError(_readableError(error));
    }
  }

  void _setError(String message) {
    _status = PlaylistsStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Could not save playlists.' : message;
  }
}
