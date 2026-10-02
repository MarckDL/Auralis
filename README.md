# Auralis

Auralis es una aplicación Android de música local desarrollada con Flutter y Dart.

## Estado actual

Sprint 10: biblioteca local conectada a un reproductor avanzado, historial y
estadísticas persistentes mediante SQLite, y Sleep Timer.

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

El progreso visual del reproductor tiene una mejora pendiente: después de un seek,
la reproducción cambia correctamente, pero el contador puede dejar de actualizarse
continuamente hasta una futura revisión de sincronización de UI.

La búsqueda del Home y el botón `See all` de Recently played siguen siendo controles
visuales pendientes de una futura revisión de UX.

El Sleep Timer permite detener la reproducción por tiempo o al finalizar la canción.
Las estadísticas registran reproducciones, tiempo escuchado, artistas y géneros más
reproducidos. Smart Playlists, Rating, letras, ecualizador, crossfade y gapless
playback permanecen fuera de alcance.

La documentación general del proyecto se encuentra en [`docs/`](docs/).
