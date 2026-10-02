# Auralis

Auralis es una aplicación Android de música local desarrollada con Flutter y Dart.

## Estado actual

Sprint 4: biblioteca local conectada a un reproductor avanzado con cola temporal,
shuffle, repeat, avance automático y reproducción en segundo plano mediante
`audio_service` y `just_audio`.

La cola no se persiste. Playlists funcionales, favoritos, historial, base de datos
y ecualizador pertenecen a sprints posteriores.

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

La documentación general del proyecto se encuentra en [`docs/`](docs/).
