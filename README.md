# Auralis

Auralis es una aplicación Android de música local desarrollada con Flutter y Dart.

## Estado actual

Sprint 3: biblioteca local conectada a un reproductor básico en primer plano,
con play, pause, seek, progreso, duración y navegación manual anterior/siguiente.

La reproducción en segundo plano, notificaciones, playlists funcionales, favoritos
y persistencia pertenecen a sprints posteriores.

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

La documentación general del proyecto se encuentra en [`docs/`](docs/).
