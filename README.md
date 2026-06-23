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
# Aporta los datos bíblicos (ver abajo)
flutter run
```

### Datos bíblicos (obligatorio)

Por respeto a los derechos de autor, **el texto bíblico no se incluye** en este
repositorio. Debes colocar tus propios datos en `assets/data/`:

- `assets/data/rv1960.json` — el texto (cualquier traducción; idealmente de
  **dominio público**).
- `assets/data/headings.json` — títulos de sección (opcional).

El formato y de dónde obtenerlos está documentado en
[`assets/data/README.md`](assets/data/README.md). Sin estos archivos la app
compila y abre, pero no mostrará texto.

> Sugerencia de fuentes libres: [bible.helloao.org](https://bible.helloao.org),
> [scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases).

## 🏗️ Build

```bash
flutter build apk --release      # Android
flutter build web                # Web (PWA)
```

La base de datos SQLite se construye en el dispositivo desde los JSON la primera
vez que se abre la app; después todo es local.

## 🧱 Stack

Flutter · Riverpod · sqflite + sqlite3 (FTS5) · google_fonts · share_plus ·
wakelock_plus

## 📄 Licencia

Código bajo **MIT** — úsalo libremente, solo mantén el crédito. Ver
[LICENSE](LICENSE).

El **texto bíblico no está cubierto** por esta licencia y puede tener derechos
de autor propios; es responsabilidad de cada quien aportarlo legalmente.
