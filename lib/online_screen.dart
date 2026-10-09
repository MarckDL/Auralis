import 'package:flutter/material.dart';

import 'models/song.dart';
import 'services/mysic_controller.dart';

class MysicOnlineScreen extends StatefulWidget {
  const MysicOnlineScreen({
    required this.controller,
    required this.onPlaySong,
    required this.onLogout,
    super.key,
  });

  final MysicController controller;
  final Future<void> Function(Song song, List<Song> queue) onPlaySong;
  final Future<void> Function() onLogout;

  @override
  State<MysicOnlineScreen> createState() => _MysicOnlineScreenState();
}

class _MysicOnlineScreenState extends State<MysicOnlineScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _search = TextEditingController();
  int _tab = 0;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _message = null);
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    }
  }

  Future<void> _createPlaylist() async {
    final input = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva lista'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    input.dispose();
    if (title != null && title.isNotEmpty) {
      await _run(() => widget.controller.createPlaylist(title));
    }
  }

  Future<void> _register() async {
    final name = TextEditingController();
    final email = TextEditingController(text: _email.text);
    final password = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear cuenta Mysic'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  helperText: 'Mínimo 8 caracteres',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, [name.text, email.text, password.text]),
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    password.dispose();
    if (values == null) return;
    await _run(
      () => widget.controller.register(values[0], values[1], values[2]),
    );
  }

  Future<void> _addToPlaylist(Song song) async {
    final playlist = await showModalBottomSheet<MysicPlaylist>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Añadir a lista')),
            for (final item in widget.controller.playlists)
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(item.title),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (playlist == null || song.remoteId == null) return;
    final ids = [...playlist.songIds];
    if (!ids.contains(song.remoteId)) ids.add(song.remoteId!);
    await _run(() => widget.controller.setPlaylistSongs(playlist, ids));
  }

  Future<void> _deletePlaylist(MysicPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text('¿Eliminar “${playlist.title}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => widget.controller.deletePlaylist(playlist));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (!controller.isConfigured || !controller.isSignedIn) {
          return _signIn(context);
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: controller.isBusy
                        ? null
                        : () => _run(controller.refresh),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Cuenta',
                    onSelected: (value) {
                      if (value == 'logout') _run(widget.onLogout);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'account',
                        enabled: false,
                        child: Text(controller.displayName),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.library_music_outlined),
                    label: Text('Biblioteca'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.queue_music_outlined),
                    label: Text('Listas'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.favorite_border_rounded),
                    label: Text('Favoritos'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (values) =>
                    setState(() => _tab = values.first),
              ),
            ),
            if (controller.isBusy) const LinearProgressIndicator(minHeight: 2),
            if (_message != null || controller.error != null)
              _errorBanner(_message ?? controller.error!),
            Expanded(
              child: _tab == 1
                  ? _playlists()
                  : _songs(favoritesOnly: _tab == 2),
            ),
          ],
        );
      },
    );
  }

  Widget _signIn(BuildContext context) {
    final controller = widget.controller;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!controller.isConfigured) ...[
          const Text(
            'El servicio en línea aún no está disponible en esta versión.',
          ),
        ] else ...[
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: controller.isBusy
                ? null
                : () =>
                      _run(() => controller.login(_email.text, _password.text)),
            child: const Text('Entrar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.isBusy ? null : _register,
            child: const Text('Crear cuenta'),
          ),
          OutlinedButton.icon(
            onPressed: controller.isBusy
                ? null
                : () => _run(controller.loginWithGoogle),
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Entrar con Google'),
          ),
        ],
        if (controller.isBusy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_message != null || controller.error != null)
          _errorBanner(_message ?? controller.error!),
      ],
    );
  }

  Widget _errorBanner(String message) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _songs({required bool favoritesOnly}) {
    final controller = widget.controller;
    final query = _search.text.trim().toLowerCase();
    final all = controller.songs.where((song) => song.path.isNotEmpty).toList();
    final songs = all
        .where(
          (song) =>
              (!favoritesOnly || controller.isFavorite(song)) &&
              (query.isEmpty ||
                  '${song.title} ${song.artist} ${song.album}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar canciones',
            ),
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    controller.isBusy
                        ? 'Cargando música…'
                        : 'No hay canciones para mostrar',
                  ),
                )
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: _artwork(song),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => widget.onPlaySong(song, songs),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opciones de canción',
                        onSelected: (value) {
                          if (value == 'favorite') {
                            _run(() => controller.toggleFavorite(song));
                          }
                          if (value == 'playlist') _addToPlaylist(song);
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'favorite',
                            child: Text(
                              controller.isFavorite(song)
                                  ? 'Quitar de favoritos'
                                  : 'Añadir a favoritos',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'playlist',
                            child: Text('Añadir a lista'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _playlists() {
    final controller = widget.controller;
    final songsById = {
      for (final song in controller.songs) song.remoteId: song,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _createPlaylist,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva lista'),
          ),
        ),
        if (controller.playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('Todavía no tienes listas en línea.')),
          ),
        for (final playlist in controller.playlists)
          ExpansionTile(
            key: ValueKey(playlist.id),
            title: Text(playlist.title),
            subtitle: Text('${playlist.songIds.length} canciones'),
            trailing: IconButton(
              tooltip: 'Eliminar lista',
              onPressed: () => _deletePlaylist(playlist),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            children: [
              for (final songId in playlist.songIds)
                if (songsById[songId] case final Song song)
                  ListTile(
                    leading: _artwork(song),
                    title: Text(song.title),
                    subtitle: Text(song.artist),
                    onTap: () => widget.onPlaySong(song, [
                      for (final id in playlist.songIds)
                        if (songsById[id] case final Song item) item,
                    ]),
                    trailing: IconButton(
                      tooltip: 'Quitar de lista',
                      onPressed: () => _run(
                        () => controller.setPlaylistSongs(
                          playlist,
                          playlist.songIds.where((id) => id != songId).toList(),
                        ),
                      ),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ),
            ],
          ),
      ],
    );
  }

  Widget _artwork(Song song) => SizedBox(
    width: 48,
    height: 48,
    child: song.artworkUrl == null
        ? const Icon(Icons.music_note_rounded)
        : Image.network(
            song.artworkUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.music_note_rounded),
          ),
  );
}
