# Datos de la app

Esta carpeta contiene los datos que la app empaqueta. **Dos archivos no están
en el repositorio** por tratarse de texto con copyright; debes aportarlos tú:

## 1. `rv1960.json` (texto bíblico)

Mapa JSON `{ "Libro": { "capítulo": { "versículo": "texto" } } }`.

```json
{
  "Génesis": {
    "1": {
      "1": "En el principio creó Dios los cielos y la tierra.",
      "2": "Y la tierra estaba desordenada y vacía..."
    }
  },
  "S. Mateo": { "1": { "1": "..." } }
}
```

Los nombres de libro deben coincidir con las claves usadas en
[`lib/data/books.dart`](../../lib/data/books.dart) (campo `jsonKey`).
Puedes usar cualquier traducción en **dominio público** (Reina-Valera 1909,
Reina-Valera Gómez, etc.) — fuentes: [bible.helloao.org](https://bible.helloao.org),
[scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases).

## 2. `headings.json` (títulos de sección, opcional)

Mapa `{ "bookId": { "capítulo": { "versículo": "título" } } }`, donde `bookId`
es el id 1–66 de `books.dart`.

```json
{ "1": { "1": { "1": "La creación" } }, "43": { "3": { "16": "..." } } }
```

Para generarlo automáticamente desde una fuente con encabezados, mira el script
[`tools/fetch_headings.ps1`](../../tools/fetch_headings.ps1).

> Sin estos archivos la app compila y abre, pero no mostrará texto.
