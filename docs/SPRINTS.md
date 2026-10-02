# Auralis — Sprint Plan

Este documento define el orden de desarrollo de Auralis.

Cada sprint debe completarse antes de avanzar al siguiente.

El objetivo no es implementar todo rápidamente, sino aprender y construir progresivamente.

---

# SPRINT 0 — Preparación

## Objetivo

Preparar el entorno de desarrollo y conseguir que una aplicación Flutter básica funcione correctamente en un dispositivo Android físico.

## Aprendizaje

* Qué es Flutter.
* Qué es Dart.
* Estructura de un proyecto Flutter.
* pubspec.yaml.
* Flutter SDK.
* Android SDK.
* ADB.
* Dispositivos físicos.
* Emuladores.
* Git.

## Tareas

1. Comprobar instalación de Flutter.
2. Comprobar Dart.
3. Comprobar Android SDK.
4. Comprobar Java/JDK requerido por el entorno Flutter/Android actual.
5. Instalar/configurar Android Studio si es necesario.
6. Configurar un dispositivo Android físico.
7. Activar depuración USB.
8. Ejecutar `flutter doctor`.
9. Ejecutar `flutter devices`.
10. Crear el proyecto Auralis.
11. Ejecutar la aplicación en el teléfono.
12. Verificar Hot Reload.
13. Crear el repositorio Git.
14. Crear el primer commit.

## Fuera de alcance

No implementar todavía:

* Audio.
* Scanner de música.
* Base de datos.
* Riverpod.
* Playlists.
* Favoritos.

## Definition of Done

Auralis abre correctamente en el celular físico.

Git está configurado.

El proyecto compila sin errores.

---

# SPRINT 1 — UI base

## Estado

Completado técnicamente: interfaz base implementada, analizada, probada e
instalada correctamente en el teléfono físico. Pendiente únicamente la revisión
visual manual del desarrollador.

## Objetivo

Crear la estructura visual principal de Auralis utilizando datos falsos.

## Aprendizaje

* Widgets.
* StatelessWidget.
* StatefulWidget.
* BuildContext.
* Row.
* Column.
* Stack.
* ListView.
* GridView.
* Navigation.
* Material 3.
* Themes.
* Responsive UI.

## Pantallas

* Home.
* Library.
* Playlists.
* Settings.
* Player.

## Componentes

* Bottom navigation.
* Song card.
* Album card.
* Artist card.
* Mini Player.
* Search field.
* Empty state.

## Datos

Utilizar datos mock.

No utilizar todavía música real del dispositivo.

## Definition of Done

La navegación funciona.

Las pantallas principales existen.

La interfaz tiene una estructura coherente.

La aplicación puede ejecutarse en el teléfono.

---

# SPRINT 2 — Biblioteca musical local

## Estado

Implementado y pendiente de validación final en el teléfono físico. La biblioteca
ya consulta audio local, solicita permisos, convierte metadatos a `Song` y muestra
estados de carga, vacío, permiso rechazado y error.

## Objetivo

Detectar archivos de música reales del dispositivo.

## Aprendizaje

* Permisos Android.
* Sistema de archivos.
* Plugins Flutter.
* Async/Await.
* Future.
* Streams.
* Metadata.

## Funcionalidades

Detectar archivos de audio compatibles.

Obtener:

* Título.
* Artista.
* Álbum.
* Género.
* Duración.
* Ruta.
* Formato.
* Portada cuando esté disponible.

## Flujo

```
Dispositivo
    ↓
Scanner
    ↓
Archivos de audio
    ↓
Metadata
    ↓
Song
    ↓
Library UI
```

## Casos especiales

Manejar:

* Canciones sin portada.
* Canciones sin artista.
* Canciones sin álbum.
* Metadatos incompletos.
* Archivos no compatibles.
* Biblioteca vacía.
* Permisos rechazados.

## Fuera de alcance

Todavía no crear:

* Base de datos completa.
* Playlists.
* Favoritos.

## Definition of Done

Auralis puede detectar música real del celular y mostrarla en Library.

---

# SPRINT 3 — Reproductor básico

## Estado

Completado técnicamente: el reproductor en primer plano conecta Library, Mini
Player y Player mediante `just_audio`, y la aplicación compila, se instala y
arranca correctamente en el teléfono físico. Pendiente únicamente la prueba
manual de reproducción con una canción real.

## Objetivo

Reproducir canciones locales.

## Aprendizaje

* Plugins Flutter.
* Streams.
* Estado.
* Controladores.
* Estados de reproducción.
* Integración de audio.

## Funcionalidades

* Play.
* Pause.
* Previous.
* Next.
* Seek.
* Progress.
* Duration.

## UI

Mini Player.

Full Player.

## Arquitectura

Separar:

UI

↓

Player State

↓

Player Service

↓

Audio Engine

## Definition of Done

El usuario puede seleccionar una canción y reproducirla.

Puede pausar.

Puede avanzar.

Puede retroceder.

Puede buscar una posición dentro de la canción.

---

# SPRINT 4 — Reproducción avanzada

## Estado

Completado técnicamente: el reproductor usa una cola temporal, shuffle, repeat,
avance automático y `audio_service` para notificación multimedia y controles de
segundo plano. Las pruebas automatizadas pasan y queda pendiente la comprobación
manual en el teléfono de bloqueo de pantalla, controles externos y variaciones
concretas del fabricante.

## Objetivo

Convertir el reproductor básico en un reproductor funcional.

## Funcionalidades

* Queue.
* Shuffle.
* Repeat.
* Repeat One.
* Next automático.
* Previous.
* Reproducción en segundo plano.

## Android

Investigar e implementar:

* Notificación multimedia.
* Controles de reproducción.
* Pantalla bloqueada.

## Definition of Done

El usuario puede escuchar una cola de canciones y controlar la reproducción incluso después de salir de la aplicación, dentro de las capacidades soportadas por Android.

---

# SPRINT 5 — Favoritos

## Estado

Completado técnicamente: los favoritos se pueden agregar y quitar desde Library,
Mini Player y Player, se muestran en la pantalla Favorites y se persisten como IDs
en un archivo JSON privado. Se probaron archivo inexistente, JSON corrupto,
duplicados, recuperación y errores de almacenamiento.

## Objetivo

Implementar el sistema de favoritos.

## Funcionalidades

* Add favorite.
* Remove favorite.
* Favorites screen.
* Estado de favorito en Song cards.

## Persistencia

El favorito debe mantenerse después de cerrar la aplicación.

## Definition of Done

El usuario puede administrar sus canciones favoritas.

---

# SPRINT 6 — Playlists

## Estado

Completado técnicamente: se pueden crear, editar, eliminar y reproducir playlists;
agregar, quitar y reordenar canciones; y persistir la información como IDs en un
archivo JSON privado. Se manejan playlists vacías, JSON corrupto, IDs duplicados,
canciones no disponibles y errores de escritura.

Hotfix aplicado: el diálogo de creación y edición mantiene su propio ciclo de vida
para evitar la aserción de Flutter al abrirlo o cerrarlo.

## Objetivo

Permitir que el usuario cree sus propias listas.

## Funcionalidades

* Crear playlist.
* Editar playlist.
* Eliminar playlist.
* Agregar canciones.
* Eliminar canciones.
* Reordenar canciones.
* Reproducir playlist.

## UI

Lista de playlists.

Detalle de playlist.

Selector de canciones.

## Definition of Done

El usuario puede crear y utilizar una playlist completa.

---

# SPRINT 7 — Artistas y álbumes

## Estado

Completado técnicamente: Library permite explorar canciones por artistas, álbumes
y géneros; cada categoría tiene detalle y puede iniciar reproducción usando la cola
actual. Las agrupaciones se calculan en memoria y usan `Unknown genre` porque
`local_audio_scan 2.0.0` no expone ese metadato.

Hotfix aplicado: la reproducción desde artistas, álbumes, géneros y favoritos
ahora conserva la colección completa como cola, incluyendo las acciones Play all.

## Objetivo

Organizar la biblioteca de forma más completa.

## Funcionalidades

Songs.

Artists.

Albums.

Genres.

## Navegación

Artist

↓

Albums

↓

Songs

## Album

Mostrar:

* Portada.
* Nombre.
* Artista.
* Canciones.
* Duración total.

## Definition of Done

La biblioteca puede explorarse por diferentes categorías.

---

# SPRINT 8 — Search + History

## Estado

Completado técnicamente: Library permite buscar por título, artista y álbum,
respetando la categoría activa. El historial temporal registra reproducciones
exitosas y alimenta Recently Played, Recently Added y Most Played. La persistencia
del historial queda reservada para Sprint 9.

## Objetivo

Encontrar música rápidamente y registrar actividad.

## Search

Buscar por:

* Song.
* Artist.
* Album.

## History

Registrar:

* Canción reproducida.
* Fecha.
* Hora.

## Secciones

* Recently Played.
* Recently Added.
* Most Played.

## Definition of Done

La búsqueda funciona.

El historial se registra correctamente.

---

# SPRINT 9 — Base de datos

## Estado

Completado técnicamente: Auralis usa SQLite local mediante `sqflite` para canciones,
artistas, álbumes, playlists, favoritos e historial. Los datos JSON de favoritos y
playlists se migran una sola vez y los archivos originales se conservan como respaldo.
La cola del reproductor continúa siendo temporal.

## Objetivo

Construir una persistencia sólida.

## Tecnología candidata

SQLite + sqflite.

Se eligió `sqflite` por su compatibilidad con Dart 3.13.4 y por mantener la
implementación Android-first sin code generation.

## Tablas/entidades

Songs.

Artists.

Albums.

Playlists.

Playlist Songs.

Favorites.

History.

## Aprendizaje

* SQLite.
* Relaciones.
* CRUD.
* Repositories.
* Data sources.
* Persistencia.

## Arquitectura

UI

↓

State

↓

Repository

↓

Database

## Definition of Done

Cerrar y volver a abrir Auralis no elimina la información relevante del usuario.

---

# SPRINT 10 — Funciones avanzadas

## Estado

Completado parcialmente: Sleep Timer y estadísticas de reproducción están
implementados y persistidos mediante SQLite. Smart Playlists y Rating quedan para
una segunda parte del sprint; letras, ecualizador, crossfade y gapless playback
solo tienen investigación pendiente.

Este sprint solamente comienza cuando las funciones principales estén estables.

## Sleep Timer

Permitir detener la reproducción después de:

* 15 minutos.
* 30 minutos.
* 45 minutos.
* 60 minutos.
* Final de canción.

## Estadísticas

Mostrar:

* Canciones reproducidas.
* Tiempo de escucha.
* Artistas más reproducidos.
* Géneros.
* Actividad por periodo.

## Smart Playlists

Crear playlists basadas en criterios.

Ejemplo:

```
Canciones no reproducidas recientemente.
```

## Rating

Permitir valorar canciones.

## Letras

Investigar primero:

* Metadata embebida.
* APIs.
* Licencias.
* Condiciones de uso.

No implementar fuentes externas sin revisar sus condiciones.

## Ecualizador

Investigar primero las capacidades reales de Android y las librerías disponibles.

## Crossfade

Investigar compatibilidad con el motor de audio elegido.

## Gapless playback

Investigar soporte real del motor de reproducción.

## Duplicados

Detectar posibles canciones duplicadas utilizando criterios apropiados.

---

# SPRINT 11 — UX + Performance

## Estado

Completado técnicamente: se corrigió la sincronización del tiempo escuchado y del
progreso tras seek, se añadió Mini Player compartido en rutas secundarias, se
conectaron búsqueda y `See all` desde Home, y se incorporaron transiciones nativas
suaves. La optimización usa APIs de Flutter sin añadir librerías de animación.

## Objetivo

Preparar Auralis para uso real.

## UX

Implementar correctamente:

* Loading states.
* Empty states.
* Error states.
* Permission states.
* Retry actions.

## Performance

Revisar:

* Uso de memoria.
* Carga de imágenes.
* Listas grandes.
* Reconstrucciones innecesarias.
* Inicio de aplicación.
* Scanner de biblioteca.

## Diseño

Revisar:

* Espaciado.
* Tipografía.
* Consistencia.
* Animaciones.
* Navegación.
* Accesibilidad.

No agregar animaciones únicamente por estética.

---

# SPRINT 12 — UX/UI y Release

## Estado

Completado técnicamente: se reforzó la sincronización de posición y estadísticas,
se implementó limpieza global de búsqueda, Mini Player interactivo con gesto
ascendente, reproducción directa desde colecciones, edición explícita de playlists,
búsqueda al agregar canciones, índice A-Z y tarjetas visuales de estadísticas.
Se usaron APIs nativas de Flutter sin añadir nuevas dependencias.

## Objetivo

Preparar una versión distribuible.

## Testing

Probar:

* Biblioteca vacía.
* Biblioteca pequeña.
* Biblioteca grande.
* Canciones sin metadata.
* Canciones sin portada.
* Permisos rechazados.
* Reproducción.
* Background playback.
* Queue.
* Shuffle.
* Repeat.
* Favoritos.
* Playlists.
* Historial.
* Cierre y reapertura de la aplicación.

## Build

Generar:

APK.

Posteriormente:

AAB.

## Documentación

Actualizar:

* README.
* PROJECT_CONTEXT.md.
* SPRINTS.md.

Añadir:

* Screenshots.
* Arquitectura.
* Stack.
* Funcionalidades.

---

# SPRINT 13 — Clean Soft UI

## Estado

Completado técnicamente: se aplicó un rediseño claro basado en tarjetas flotantes,
bordes redondeados, sombras suaves, Mini Player destacado y navegación inferior
flotante. El tema oscuro permanece disponible desde Settings y no se añadieron
dependencias visuales nuevas.

## Diseño

* Fondo claro `#F5F6F8`.
* Tarjetas blancas con radios amplios y elevación sutil.
* Portadas redondeadas.
* Tipografía con jerarquía entre títulos y metadatos.
* Acentos violeta/azul para acciones principales.
* Contraste y áreas táctiles compatibles con accesibilidad básica.

## Alcance preservado

Se conservaron reproducción, cola, background playback, favoritos, playlists,
historial, estadísticas y Sleep Timer. No se incorporaron fuentes externas ni
librerías visuales adicionales.

La pantalla Home sigue la referencia visual con cabecera, búsqueda tipo cápsula,
hero de highlights y tarjetas de álbumes. El reproductor publica ticks de posición
desde `just_audio` para evitar que el contador quede congelado.
* Instalación.
* Decisiones técnicas.

---

# REGLAS GENERALES DE LOS SPRINTS

## 1. No adelantarse

No implementar características de futuros sprints sin una razón técnica clara.

## 2. Primero entender

Antes de implementar una tecnología nueva, explicar brevemente:

* Qué es.
* Para qué sirve.
* Por qué Auralis la necesita.

## 3. Plan antes de cambios grandes

Antes de modificar muchas partes del proyecto:

1. Analizar el código existente.
2. Identificar archivos afectados.
3. Proponer plan.
4. Esperar aprobación si el cambio es grande o irreversible.
5. Implementar.
6. Probar.

## 4. Mantener el proyecto funcional

Después de cada tarea importante:

```
Implementar
    ↓
Ejecutar
    ↓
Probar
    ↓
Corregir
    ↓
Commit
```

## 5. No sobrearquitecturar

La arquitectura debe crecer con el proyecto.

No crear abstracciones innecesarias solamente porque son consideradas "best practice".

## 6. No ocultar errores

Si una dependencia, API o plugin presenta problemas de compatibilidad:

* Explicar el problema.
* Investigar alternativas.
* No inventar APIs.
* No asumir que una librería soporta una función sin comprobarlo.

## 7. Priorizar Android inicialmente

Auralis se desarrollará y probará primero en Android.

La compatibilidad con iOS será una etapa posterior.

---

# Flujo de trabajo recomendado

Para cada sprint:

```
1. Leer PROJECT_CONTEXT.md
2. Leer este SPRINTS.md
3. Revisar estado actual del repositorio
4. Identificar sprint actual
5. Crear plan
6. Implementar
7. Probar en dispositivo físico
8. Corregir errores
9. Actualizar documentación
10. Crear commit
11. Pasar al siguiente sprint
```

El objetivo no es terminar Auralis lo más rápido posible.

El objetivo es que el desarrollador comprenda cómo se construyó cada parte de la aplicación.
