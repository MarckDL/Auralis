import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/song.dart';

class MysicApiException implements Exception {
  const MysicApiException(this.message, [this.statusCode = 0]);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class MysicPlaylist {
  const MysicPlaylist({
    required this.id,
    required this.title,
    required this.songIds,
  });

  final String id;
  final String title;
  final List<String> songIds;

  factory MysicPlaylist.fromJson(Map<String, dynamic> json) => MysicPlaylist(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    songIds: (json['songIds'] as List<dynamic>? ?? const []).cast<String>(),
  );
}

abstract interface class MysicSessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureMysicSessionStore implements MysicSessionStore {
  const SecureMysicSessionStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MysicController extends ChangeNotifier {
  MysicController({http.Client? client, MysicSessionStore? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const SecureMysicSessionStore();

  static const _configuredUrl = String.fromEnvironment(
    'MYSIC_API_URL',
    defaultValue: 'https://myslc.duckdns.org',
  );
  static const _googleClientId = String.fromEnvironment(
    'MYSIC_GOOGLE_WEB_CLIENT_ID',
  );
  static const _serverKey = 'mysic_server_url';
  static const _sessionKey = 'mysic_session_cookie';

  final http.Client _client;
  final MysicSessionStore _storage;
  String _serverUrl = _configuredUrl;
  String? _cookie;
  Map<String, dynamic>? _user;
  List<Song> _songs = const [];
  List<MysicPlaylist> _playlists = const [];
  Set<String> _favoriteSongIds = {};
  bool _busy = false;
  String? _error;

  String get serverUrl => _serverUrl;
  bool get isConfigured => _serverUrl.isNotEmpty;
  bool get isSignedIn => _user != null;
  bool get isBusy => _busy;
  String? get error => _error;
  String get displayName => _user?['username'] as String? ?? '';
  List<Song> get songs => List.unmodifiable(_songs);
  List<MysicPlaylist> get playlists => List.unmodifiable(_playlists);
  bool isFavorite(Song song) => _favoriteSongIds.contains(song.remoteId);

  Uri get _apiRoot {
    final base = _serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(base.endsWith('/api') ? base : '$base/api');
  }

  Future<void> initialize() async {
    _serverUrl = _configuredUrl;
    await _storage.delete(_serverKey);
    _cookie = await _storage.read(_sessionKey);
    notifyListeners();
    if (!isConfigured || _cookie == null) return;
    try {
      final data = await _request('GET', '/auth/me');
      _user = data['user'] as Map<String, dynamic>?;
      await refresh();
    } on MysicApiException catch (error) {
      if (error.statusCode != 401) _error = error.message;
      notifyListeners();
    }
  }

  Future<void> setServerUrl(String value) async {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null ||
        !parsed.hasAuthority ||
        (parsed.scheme != 'https' &&
            !(kDebugMode && parsed.scheme == 'http'))) {
      throw const MysicApiException(
        'Ingresa una URL HTTPS válida del servidor Mysic.',
      );
    }
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized == _serverUrl) return;
    _serverUrl = normalized;
    await _storage.write(_serverKey, normalized);
    await _clearSession();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await _authenticate('/auth/login', {
      'email': email.trim(),
      'password': password,
      'remember': true,
    });
  }

  Future<void> register(String username, String email, String password) async {
    await _authenticate('/auth/register', {
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
    });
  }

  Future<void> loginWithGoogle() async {
    final configuredClientId = _googleClientId.isEmpty
        ? (await _request('GET', '/client-config'))['googleClientId'] as String?
        : _googleClientId;
    if (configuredClientId == null || configuredClientId.isEmpty) {
      throw const MysicApiException(
        'Falta configurar el cliente Google de Mysic.',
      );
    }
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(serverClientId: configuredClientId);
    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const MysicApiException('Google no entregó una credencial válida.');
    }
    await _authenticate('/auth/google', {
      'credential': idToken,
      'remember': true,
    });
  }

  Future<void> _authenticate(String path, Map<String, dynamic> body) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _request('POST', path, body: body);
      if (_cookie == null) {
        throw const MysicApiException('El servidor no inició una sesión.');
      }
      _user = data['user'] as Map<String, dynamic>?;
      await refresh();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!isSignedIn) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _request('GET', '/catalog/songs'),
        _request('GET', '/favorites'),
        _request('GET', '/playlists'),
      ]);
      final cookie = _cookie;
      if (cookie == null) return;
      _songs = (results[0]['songs'] as List<dynamic>? ?? const [])
          .map((raw) => _songFromJson(raw as Map<String, dynamic>, cookie))
          .toList(growable: false);
      _favoriteSongIds =
          (results[1]['favorites']?['songs'] as List<dynamic>? ?? const [])
              .cast<String>()
              .toSet();
      _playlists = (results[2]['playlists'] as List<dynamic>? ?? const [])
          .map((raw) => MysicPlaylist.fromJson(raw as Map<String, dynamic>))
          .toList(growable: false);
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Song _songFromJson(Map<String, dynamic> json, String cookie) {
    final id = json['id'] as String;
    final artwork = json['artwork'] as String?;
    final audioPath = json['audioPath'] as String?;
    final album = json['album'] as Map<String, dynamic>?;
    return Song(
      id: 'online:$id',
      remoteId: id,
      title: json['title'] as String? ?? 'Sin título',
      artist: json['artist'] as String? ?? 'Artista desconocido',
      album:
          album?['title'] as String? ??
          json['albumTitle'] as String? ??
          'Sin álbum',
      duration: Duration(
        seconds: (json['durationSeconds'] as num?)?.round() ?? 0,
      ),
      path: audioPath == null
          ? ''
          : _apiRoot.resolve('${_apiRoot.path}$audioPath').toString(),
      format: 'stream',
      mimeType: 'audio/mpeg',
      artworkUrl: artwork == null
          ? null
          : _apiRoot.resolve('${_apiRoot.path}$artwork').toString(),
      requestHeaders: {'Cookie': cookie},
    );
  }

  Future<void> toggleFavorite(Song song) async {
    final id = song.remoteId;
    if (id == null) return;
    final wasFavorite = _favoriteSongIds.contains(id);
    await _request(
      wasFavorite ? 'DELETE' : 'PUT',
      '/favorites/song/${Uri.encodeComponent(id)}',
    );
    if (wasFavorite) {
      _favoriteSongIds.remove(id);
    } else {
      _favoriteSongIds.add(id);
    }
    notifyListeners();
  }

  Future<void> createPlaylist(String title) async {
    await _request(
      'POST',
      '/playlists',
      body: {'title': title, 'songIds': <String>[]},
    );
    await refresh();
  }

  Future<void> setPlaylistSongs(
    MysicPlaylist playlist,
    List<String> songIds,
  ) async {
    await _request(
      'PATCH',
      '/playlists/${Uri.encodeComponent(playlist.id)}',
      body: {'songIds': songIds},
    );
    await refresh();
  }

  Future<void> deletePlaylist(MysicPlaylist playlist) async {
    await _request('DELETE', '/playlists/${Uri.encodeComponent(playlist.id)}');
    await refresh();
  }

  Future<void> logout() async {
    try {
      if (_cookie != null) await _request('POST', '/auth/logout');
    } finally {
      await _clearSession();
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    _cookie = null;
    _user = null;
    _songs = const [];
    _playlists = const [];
    _favoriteSongIds = {};
    await _storage.delete(_sessionKey);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!isConfigured) {
      throw const MysicApiException('Configura el servidor Mysic.');
    }
    final request = http.Request(
      method,
      _apiRoot.resolve('${_apiRoot.path}$path'),
    );
    request.headers['Accept'] = 'application/json';
    if (_cookie != null) request.headers['Cookie'] = _cookie!;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw const MysicApiException('No se pudo conectar con Mysic.');
    }
    final setCookie = response.headers['set-cookie'];
    final session = setCookie == null
        ? null
        : RegExp(r'(?:^|,\s*)mysic_session=([^;]*)')
              .firstMatch(setCookie)
              ?.group(1);
    if (session != null && session.isNotEmpty) {
      _cookie = 'mysic_session=$session';
      await _storage.write(_sessionKey, _cookie!);
    }
    if (response.statusCode == 401 && _user != null) {
      await _clearSession();
      notifyListeners();
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MysicApiException(
        data['message'] as String? ?? 'Error de Mysic.',
        response.statusCode,
      );
    }
    return data;
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
