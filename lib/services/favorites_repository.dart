import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef FavoritesFileProvider = Future<File> Function();

class FavoritesRepository {
  FavoritesRepository({this._fileProvider});

  static const fileName = 'auralis_favorites.json';
  static const formatVersion = 1;

  final FavoritesFileProvider? _fileProvider;

  Future<Set<String>> loadFavoriteIds() async {
    try {
      final file = await _file();
      if (!await file.exists()) return <String>{};

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return <String>{};
      final ids = decoded['favoriteIds'];
      if (ids is! List) return <String>{};
      return ids.whereType<String>().where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveFavoriteIds(Set<String> ids) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final payload = <String, Object>{
      'version': formatVersion,
      'favoriteIds': ids.toList()..sort(),
    };
    await file.writeAsString(jsonEncode(payload));
  }

  Future<File> _file() async {
    if (_fileProvider != null) return _fileProvider();
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }
}
