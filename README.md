# Auralis

Auralis es una aplicación Android de música local desarrollada con Flutter y Dart.

## Estado actual

Sprint 13: biblioteca local conectada a un reproductor avanzado, historial y
estadísticas persistentes mediante SQLite, Sleep Timer y una interfaz Clean Soft UI.

La cola no se persiste. Favoritos, playlists e historial se guardan localmente en
SQLite; la base de datos no se sincroniza con ningún servidor.

Los archivos JSON anteriores de favoritos y playlists se migran una sola vez a la
base de datos SQLite, conservando los archivos originales como respaldo.

Los artistas, álbumes y géneros se calculan en memoria a partir de la biblioteca
escaneada. El plugin actual no expone género, por lo que las canciones sin ese
metadato se agrupan como `Unknown genre`.

La aplicación se desarrolla con Flutter, Dart, VS Code, Android SDK mediante herramientas de línea de comandos y Git. No se utiliza Android Studio ni Android Emulator.

## Ejecutar el proyecto

Conecta el teléfono por USB, activa la depuración USB y autoriza el ordenador. Después verifica el dispositivo:

```text
adb devices
flutter devices
```

Ejecuta la aplicación indicando el identificador del teléfono:

```text
flutter run -d <device-id>
```

## Verificaciones

```text
flutter analyze
flutter test
```

En Android, el reproductor también expone una notificación multimedia y controles
del sistema mientras la reproducción está activa.

El progreso visual del reproductor se mantiene sincronizado después de un seek y la
búsqueda del Home y el botón `See all` de Recently played ya son funcionales.

El Sleep Timer permite detener la reproducción por tiempo o al finalizar la canción.
Las estadísticas registran reproducciones, tiempo escuchado, artistas y géneros más
reproducidos. Smart Playlists, Rating, letras, ecualizador, crossfade y gapless
playback permanecen fuera de alcance.

Sprint 11 mejora la sincronización del progreso y del tiempo escuchado, muestra el
Mini Player en rutas secundarias, conecta la búsqueda y `See all` de Home, y añade
transiciones nativas suaves. La optimización usa widgets const, listas eficientes,
`RepaintBoundary` y escritura serializada de estadísticas; no se añadió una librería
de animaciones.

Sprint 12 añade limpieza global de búsqueda, Mini Player con gesto ascendente,
reproducción directa desde playlists y álbumes, edición explícita de playlists,
búsqueda al agregar canciones, índice alfabético A-Z y tarjetas visuales para
estadísticas. Los modales usan desenfoque nativo y no se añadieron dependencias nuevas.

Sprint 13 aplica un tema claro predeterminado con tema oscuro opcional, tarjetas
blancas redondeadas, sombras suaves, portadas con esquinas redondeadas, Mini Player
flotante y navegación inferior tipo cápsula. El rediseño usa Material 3 y APIs
nativas de Flutter, sin librerías visuales adicionales.

La posición del reproductor se publica desde `just_audio` mediante
`AudioPlayer.positionStream`, por lo que el contador, la seekbar y el tiempo
escuchado reciben actualizaciones reales durante la reproducción.

La documentación general del proyecto se encuentra en [`docs/`](docs/).
