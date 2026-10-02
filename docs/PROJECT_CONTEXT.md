# Auralis — Project Context

## 1. Descripción del proyecto

Auralis es una aplicación móvil de reproducción y gestión de música local desarrollada con Flutter y Dart.

La primera versión de Auralis estará enfocada exclusivamente en la música almacenada en el dispositivo del usuario.

La aplicación debe detectar archivos de audio disponibles en el dispositivo, leer sus metadatos y presentarlos en una biblioteca musical organizada.

El objetivo no es crear solamente un reproductor básico, sino construir progresivamente una aplicación de música moderna, bien estructurada y con características similares a las aplicaciones reales de reproducción musical.

Una posible evolución futura será integrar Auralis con servicios como Navidrome u otras fuentes de música remota. Esa integración NO forma parte del MVP inicial.

---

## 2. Objetivos principales

Auralis debe permitir:

* Detectar música almacenada localmente en el dispositivo.
* Leer metadatos de las canciones.
* Mostrar canciones.
* Mostrar artistas.
* Mostrar álbumes.
* Mostrar géneros.
* Reproducir canciones.
* Pausar y reanudar.
* Avanzar y retroceder.
* Buscar música.
* Crear playlists.
* Agregar y eliminar canciones de playlists.
* Marcar canciones como favoritas.
* Mantener historial de reproducción.
* Administrar una cola de reproducción.
* Utilizar shuffle.
* Utilizar repeat.
* Continuar reproduciendo música en segundo plano.
* Mostrar controles de reproducción mediante las capacidades del sistema Android.
* Mantener una interfaz moderna, limpia y responsive.

Las funciones avanzadas se incorporarán progresivamente.

---

## 3. Filosofía del proyecto

Auralis también es un proyecto de aprendizaje.

El desarrollador está aprendiendo Flutter y Dart mientras construye la aplicación.

Por lo tanto, el código debe priorizar:

* Claridad.
* Mantenibilidad.
* Arquitectura comprensible.
* Buenas prácticas.
* Separación de responsabilidades.
* Explicaciones de conceptos nuevos.
* Evolución progresiva.

No se debe introducir complejidad innecesaria solamente para hacer que el proyecto parezca más profesional.

La arquitectura debe crecer junto con las necesidades reales del proyecto.

---

## 4. Stack tecnológico

### Lenguaje

Dart.

### Framework

Flutter.

### Plataforma inicial

Android.

### IDE

Puede utilizarse:

* Visual Studio Code.
* Android Studio.

El desarrollo principal puede realizarse en Visual Studio Code.

Android Studio se utilizará principalmente para las herramientas del ecosistema Android, incluyendo SDK, emulador y configuración del dispositivo cuando sea necesario.

### Control de versiones

Git.

Repositorio remoto:

GitHub.

### Estado

Se prevé utilizar Riverpod.

No introducir Riverpod hasta que el proyecto llegue al punto donde realmente sea necesario.

### Audio

Se prevé utilizar:

* just_audio.
* audio_service o una solución equivalente para reproducción en segundo plano.

Las dependencias definitivas deben comprobarse antes de implementarlas.

### Persistencia

Inicialmente puede utilizarse almacenamiento sencillo.

En una etapa posterior se utilizará SQLite mediante Drift o una alternativa apropiada.

---

## 5. Plataforma objetivo inicial

El primer objetivo es Android.

La aplicación se probará principalmente en un dispositivo Android físico.

También puede utilizarse Android Emulator para pruebas generales.

El dispositivo físico será especialmente importante para comprobar:

* Permisos.
* Archivos de audio reales.
* Reproducción.
* Reproducción en segundo plano.
* Notificaciones.
* Controles de pantalla bloqueada.
* Consumo de batería.
* Comportamiento real del sistema.

No asumir que el comportamiento del emulador representa exactamente al de un teléfono físico.

---

## 6. Arquitectura prevista

La arquitectura evolucionará progresivamente.

Estructura aproximada:

lib/

```
core/
    theme/
    router/
    constants/
    utils/

features/
    music/
    player/
    playlists/
    favorites/
    artists/
    albums/
    search/
    settings/

data/
    models/
    repositories/
    datasources/

main.dart
```

No es necesario crear todas estas carpetas desde el inicio.

Crear estructuras solamente cuando exista una necesidad real.

---

## 7. Principios de arquitectura

Se debe intentar mantener una separación clara entre:

### UI

Responsable de mostrar información y recibir interacción del usuario.

### Estado

Responsable de representar el estado actual de la aplicación.

### Lógica de negocio

Responsable de las reglas de la aplicación.

### Servicios

Responsables de interactuar con capacidades externas, por ejemplo:

* Audio.
* Sistema de archivos.
* Permisos.
* Base de datos.

### Repositorios

Responsables de abstraer el acceso a datos.

No colocar toda la lógica dentro de widgets.

---

## 8. Modelo conceptual inicial

La aplicación eventualmente trabajará con entidades como:

### Song

* id
* title
* artist
* album
* genre
* duration
* path
* artwork
* format

### Artist

* id
* name
* artwork

### Album

* id
* name
* artist
* artwork
* songs

### Playlist

* id
* name
* description
* artwork
* songs

### Favorite

Referencia a una canción favorita.

### PlaybackHistory

* song
* playedAt

Estas estructuras pueden cambiar cuando la implementación real revele nuevas necesidades.

---

## 9. Diseño de interfaz

Auralis debe tener una interfaz moderna y limpia.

Principios:

* Material 3.
* Dark mode.
* Buena jerarquía visual.
* Espaciado consistente.
* Tipografía legible.
* Animaciones moderadas.
* Responsive layouts.
* Estados de carga.
* Estados vacíos.
* Estados de error.
* Feedback visual.

La aplicación no debe sobrecargarse de animaciones únicamente para hacerla parecer moderna.

La prioridad es:

1. Usabilidad.
2. Claridad.
3. Rendimiento.
4. Consistencia visual.
5. Animaciones.

---

## 10. Navegación principal

La aplicación tendrá inicialmente una estructura similar a:

Home

Library

Playlists

Settings

El reproductor completo será accesible mediante el Mini Player.

La Library podrá organizarse mediante:

* Songs.
* Artists.
* Albums.
* Genres.

La estructura exacta puede cambiar durante el desarrollo.

---

## 11. Mini Player

El Mini Player debe aparecer cuando exista una canción activa.

Debe mostrar como mínimo:

* Portada.
* Título.
* Artista.
* Play/Pause.

Al tocarlo debe abrir el reproductor completo.

---

## 12. Reproductor completo

Debe incluir progresivamente:

* Portada.
* Título.
* Artista.
* Progreso.
* Duración.
* Seek.
* Previous.
* Play/Pause.
* Next.
* Shuffle.
* Repeat.

Posteriormente:

* Cola.
* Sleep timer.
* Crossfade.
* Ecualizador.
* Letras.
* Otras funciones avanzadas.

---

## 13. Uso de Codex

Codex será utilizado como asistente de desarrollo y aprendizaje.

No debe tratarse únicamente como un generador automático de código.

El objetivo es que el desarrollador comprenda progresivamente el proyecto.

Cuando se introduzca un concepto importante de Flutter o Dart, Codex debe explicar:

* Qué es.
* Para qué sirve.
* Por qué se está utilizando.
* Cómo funciona dentro de Auralis.

Antes de realizar cambios importantes, Codex debe analizar el estado actual del proyecto.

Para cada sprint se debe trabajar de manera incremental.

---

## 14. Regla importante para Codex

No implementar funciones de futuros sprints sin necesidad.

Si se está trabajando en Sprint 2, no implementar automáticamente:

* Playlists.
* Favoritos.
* Base de datos completa.
* Ecualizador.
* Navidrome.
* Sistema de cuentas.

Las funciones futuras deben permanecer fuera de alcance hasta su sprint correspondiente.

---

## 15. Definition of Done

Una tarea se considera terminada cuando:

* El código compila.
* La funcionalidad funciona.
* No existen errores evidentes relacionados con la tarea.
* Se probaron los casos principales.
* El código mantiene una estructura razonable.
* Se eliminaron archivos o código innecesario generado durante la implementación.
* La documentación se actualizó cuando corresponda.
* Se realizó un commit.

---

## 16. Git

Utilizar commits pequeños y descriptivos.

Ejemplos:

```
chore: initialize flutter project

feat: add music library screen

feat: detect local audio files

feat: add audio player

feat: add favorites

fix: handle missing album artwork

refactor: separate player service

docs: update project context
```

No hacer commits gigantes que mezclen muchas funcionalidades independientes.

---

## 17. Estado actual del proyecto

Este documento corresponde al contexto general de Auralis.

El estado exacto del código debe comprobarse directamente en el repositorio antes de realizar cambios.

Actualmente Auralis tiene completados los Sprints 0, 1, 2, 3, 4, 5 y 6. El reproductor
usa `just_audio` en primer plano y `audio_service` para cola temporal, shuffle,
repeat, avance automático, notificación multimedia y controles en segundo plano.
Los favoritos se guardan como IDs en un archivo JSON privado; la base de datos
queda reservada para Sprint 9. Las playlists también se guardan como JSON y
almacenan IDs de canciones para conservar su orden.

---

## 18. Fuera del MVP inicial

No implementar inicialmente:

* Navidrome.
* Streaming remoto.
* Sistema de cuentas.
* Backend propio.
* Sincronización entre dispositivos.
* Sistema de suscripciones.
* Pagos.
* Red social.
* Recomendaciones basadas en servidores.

Estas características pueden evaluarse en una futura versión.

---

## 19. Visión futura

Una posible evolución sería:

Versión 1:

```
Música local
    ↓
Biblioteca
    ↓
Reproductor
    ↓
Playlists
    ↓
Favoritos
    ↓
Historial
```

Versión 2:

```
Funciones avanzadas
    ↓
Estadísticas
    ↓
Smart playlists
    ↓
Letras
    ↓
Ecualizador
    ↓
Mejoras de audio
```

Versión 3:

```
Integración con servidores
    ↓
Navidrome
    ↓
Sincronización
    ↓
Música local + remota
```

La versión 3 no debe afectar la simplicidad del MVP inicial.
