# Auralis

Auralis es una aplicación Android de música local desarrollada con Flutter y Dart.

## Estado actual

Sprint 0: proyecto Flutter inicializado y preparado para ejecutarse en un teléfono Android físico.

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
