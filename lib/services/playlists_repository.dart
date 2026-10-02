import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/playlist.dart';

typedef PlaylistsFileProvider = Future<File> Function();

class PlaylistsRepository {
  PlaylistsRepository({this._fileProvider});

  static const fileName = 'auralis_playlists.json';
  static const formatVersion = 1;

  final PlaylistsFileProvider? _fileProvider;

  Future<List<Playlist>> loadPlaylists() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return const [];
      final rawPlaylists = decoded['playlists'];
      if (rawPlaylists is! List) return const [];

      final seenIds = <String>{};
      return rawPlaylists
          .whereType<Map>()
          .map((json) => Playlist.fromJson(Map<String, dynamic>.from(json)))
          .where((playlist) =>
              playlist.id.isNotEmpty &&
              playlist.name.trim().isNotEmpty &&
              seenIds.add(playlist.id))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final payload = <String, Object>{
      'version': formatVersion,
      'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(payload));
  }

  Future<File> _file() async {
    if (_fileProvider != null) return _fileProvider();
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }
}
