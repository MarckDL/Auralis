import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auralis/services/mysic_controller.dart';

class MemorySessionStore implements MysicSessionStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'login loads remote music, favorites and playlists with session',
    () async {
      final store = MemorySessionStore();
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        switch (request.url.path) {
          case '/api/auth/login':
            return http.Response(
              jsonEncode({
                'user': {'username': 'Marck'},
              }),
              200,
              headers: {'set-cookie': 'mysic_session=abc123; HttpOnly; Path=/'},
            );
          case '/api/catalog/songs':
            return http.Response(
              jsonEncode({
                'songs': [
                  {
                    'id': 'song-1',
                    'title': 'Una canción',
                    'artist': 'Artista',
                    'albumTitle': 'Álbum',
                    'durationSeconds': 180,
                    'audioPath': '/catalog/media/media-1/stream',
                    'artwork': '/catalog/images/image-1',
                  },
                ],
              }),
              200,
            );
          case '/api/favorites':
            return http.Response(
              jsonEncode({
                'favorites': {
                  'songs': ['song-1'],
                },
              }),
              200,
            );
          case '/api/playlists':
            return http.Response(
              jsonEncode({
                'playlists': [
                  {
                    'id': 'list-1',
                    'title': 'Mi lista',
                    'songIds': ['song-1'],
                  },
                ],
              }),
              200,
            );
          case '/api/auth/logout':
            return http.Response('', 204);
        }
        return http.Response('{}', 404);
      });
      final controller = MysicController(client: client, storage: store);

      await controller.setServerUrl('https://mysic.test');
      await controller.login('marck@example.com', 'password123');

      expect(controller.isSignedIn, isTrue);
      expect(controller.displayName, 'Marck');
      expect(
        controller.songs.single.path,
        'https://mysic.test/api/catalog/media/media-1/stream',
      );
      expect(
        controller.songs.single.requestHeaders['Cookie'],
        'mysic_session=abc123',
      );
      expect(controller.isFavorite(controller.songs.single), isTrue);
      expect(controller.playlists.single.songIds, ['song-1']);
      expect(
        requests
            .skip(1)
            .every(
              (request) => request.headers['Cookie'] == 'mysic_session=abc123',
            ),
        isTrue,
      );

      await controller.logout();
      expect(controller.isSignedIn, isFalse);
      expect(store.values.containsKey('mysic_session_cookie'), isFalse);
      controller.dispose();
    },
  );

  test('expired session clears online state', () async {
    final store = MemorySessionStore();
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        return http.Response(
          jsonEncode({
            'user': {'username': 'Marck'},
          }),
          200,
          headers: {'set-cookie': 'mysic_session=abc123; HttpOnly'},
        );
      }
      if (request.url.path == '/api/favorites/song/song-1') {
        return http.Response(jsonEncode({'message': 'La sesión venció.'}), 401);
      }
      if (request.url.path == '/api/catalog/songs') {
        return http.Response(
          jsonEncode({
            'songs': [
              {
                'id': 'song-1',
                'title': 'Una canción',
                'artist': 'Artista',
                'audioPath': '/catalog/media/1/stream',
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/favorites') {
        return http.Response(
          jsonEncode({
            'favorites': {'songs': []},
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'playlists': []}), 200);
    });
    final controller = MysicController(client: client, storage: store);
    await controller.setServerUrl('https://mysic.test');
    await controller.login('marck@example.com', 'password123');

    await expectLater(
      controller.toggleFavorite(controller.songs.single),
      throwsA(isA<MysicApiException>()),
    );
    expect(controller.isSignedIn, isFalse);
    expect(controller.songs, isEmpty);
    expect(store.values.containsKey('mysic_session_cookie'), isFalse);
    controller.dispose();
  });
}
