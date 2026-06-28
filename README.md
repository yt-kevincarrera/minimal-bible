# La Biblia — minimal

Una app de Biblia **mínima, bonita y 100% offline**. Sin anuncios, sin cuentas,
sin internet. Solo la Palabra, bien organizada, con un buscador rápido.

Hecha con Flutter por **Kevin Carrera**.

## ✨ Características

- 📖 Lectura cómoda: tipografía serif, tamaño ajustable, tema claro/oscuro y
  varios colores de acento.
- 🔎 Búsqueda instantánea con **SQLite FTS5** (ignora tildes: "jesus" encuentra
  "Jesús"), totalmente offline.
- 🗂️ Libros agrupados por Antiguo/Nuevo Testamento, con sinopsis y navegación
  por capítulos.
- 🎚️ Navegador lateral de versículos (deslizar para saltar, con vista previa).
- 🔊 Lectura en voz alta con el motor TTS del sistema: play/pausa, resaltado del
  versículo en curso y velocidad ajustable (0.5×–2×).
- ⭐ Favoritos, **bibliotecas** (colecciones) y **colores** para marcar
  versículos; se guardan y agrupan por lote.
- 📊 Estadísticas de lectura: progreso por libro, racha, tiempo, calendario,
  libro/capítulo más leído y libros terminados.
- 💾 Respaldo (exportar/importar) de todos tus datos.
- 🔆 Opción de mantener la pantalla encendida mientras lees.

## 🚀 Empezar

Requiere [Flutter](https://docs.flutter.dev/get-started/install) (canal stable).

```bash
flutter pub get

# Aporta los datos bíblicos (dominio público) con un par de scripts:
powershell -ExecutionPolicy Bypass -File tools/fetch_bible.ps1     # texto
powershell -ExecutionPolicy Bypass -File tools/fetch_headings.ps1  # títulos (opcional)

flutter run
```

### Datos bíblicos (obligatorio)

Por respeto a los derechos de autor, **el texto bíblico no se incluye** en este
repositorio. Los scripts de arriba lo descargan de una fuente de **dominio
público** y lo dejan con el formato y los nombres de libro exactos que la app
espera — guía completa (y forma manual) en
[`assets/data/README.md`](assets/data/README.md).

Sin esos archivos la app compila y abre, pero no mostrará texto.

> ¿Lo quieres directo? Escríbeme: **kevin.ccdo@gmail.com**.

## 🏗️ Build

```bash
flutter build apk --release      # Android (APK universal, ~61 MB)
flutter build web                # Web (PWA)
```

Para un APK **mucho más liviano** (~26-32 MB), sepáralo por arquitectura — el
universal carga 3 arquitecturas a la vez:

```bash
flutter build apk --release --split-per-abi
# o, en Windows:
powershell -ExecutionPolicy Bypass -File tools/build_apk.ps1
```

Genera un APK por arquitectura; reparte el de **`arm64-v8a`** (casi todos los
teléfonos modernos) o el `armeabi-v7a` para equipos viejos de 32 bits.

La base de datos SQLite se construye en el dispositivo desde los JSON la primera
vez que se abre la app; después todo es local.

## 🧱 Stack

Flutter · Riverpod · sqflite + sqlite3 (FTS5) · fuentes empaquetadas (offline) ·
flutter_tts · share_plus · wakelock_plus

## 📄 Licencia

Código bajo **MIT** — úsalo libremente, solo mantén el crédito. Ver
[LICENSE](LICENSE).

El **texto bíblico no está cubierto** por esta licencia y puede tener derechos
de autor propios; es responsabilidad de cada quien aportarlo legalmente.
