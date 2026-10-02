# Auralis

Auralis es una aplicación Android de música local desarrollada con Flutter y Dart.

## Estado actual

Sprint 6: biblioteca local conectada a un reproductor avanzado, favoritos y
playlists persistentes mediante archivos JSON privados de la aplicación.

La cola no se persiste. Favoritos y playlists sobreviven al cierre de la aplicación;
historial, base de datos y ecualizador pertenecen a sprints posteriores.

Las playlists actuales usan persistencia JSON provisional. La base de datos SQLite
se reservará para Sprint 9.

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

La documentación general del proyecto se encuentra en [`docs/`](docs/).
