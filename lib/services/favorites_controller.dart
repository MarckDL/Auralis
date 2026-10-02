import 'package:flutter/foundation.dart';

import '../models/song.dart';
import 'favorites_repository.dart';

enum FavoritesStatus { idle, loading, ready, error }

class FavoritesController extends ChangeNotifier {
  FavoritesController({FavoritesRepository? repository})
      : _repository = repository ?? FavoritesRepository();

  final FavoritesRepository _repository;
  final Set<String> _favoriteIds = <String>{};
  FavoritesStatus _status = FavoritesStatus.idle;
  String? _errorMessage;

  FavoritesStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  bool isFavorite(Song song) => _favoriteIds.contains(song.id);

  Future<void> load() async {
    _status = FavoritesStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _favoriteIds
        ..clear()
        ..addAll(await _repository.loadFavoriteIds());
      _status = FavoritesStatus.ready;
    } catch (error) {
      _status = FavoritesStatus.error;
      _errorMessage = _readableError(error);
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(Song song) {
    return isFavorite(song) ? removeFavorite(song) : addFavorite(song);
  }

  Future<void> addFavorite(Song song) async {
    if (isFavorite(song)) return;
    await _update(() => _favoriteIds.add(song.id));
  }

  Future<void> removeFavorite(Song song) async {
    if (!isFavorite(song)) return;
    await _update(() => _favoriteIds.remove(song.id));
  }

  Future<void> _update(bool Function() change) async {
    final previous = Set<String>.of(_favoriteIds);
    change();
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.saveFavoriteIds(_favoriteIds);
      _status = FavoritesStatus.ready;
    } catch (error) {
      _favoriteIds
        ..clear()
        ..addAll(previous);
      _status = FavoritesStatus.error;
      _errorMessage = _readableError(error);
    }
    notifyListeners();
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Could not save favorites.' : message;
  }
}
