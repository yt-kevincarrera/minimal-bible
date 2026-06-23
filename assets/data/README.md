# Datos de la app (cómo dejarla funcionando)

La app necesita dos archivos en esta carpeta que **no están en el repositorio**
por derechos de autor. Aquí tienes la forma fácil y la manual.

| Archivo | ¿Obligatorio? | Qué es |
|---|---|---|
| `rv1960.json` | Sí | El texto bíblico |
| `headings.json` | No (opcional) | Títulos de sección (perícopas) |

---

## ✅ Forma fácil (recomendada) — 2 comandos

Desde la **raíz del proyecto**, en PowerShell (Windows):

```powershell
# 1) Texto bíblico (traducción de dominio público) → assets/data/rv1960.json
powershell -ExecutionPolicy Bypass -File tools/fetch_bible.ps1

# 2) Títulos de sección → assets/data/headings.json
powershell -ExecutionPolicy Bypass -File tools/fetch_headings.ps1
```

Listo: `flutter run` y a leer. Los scripts descargan de la API gratuita
[bible.helloao.org](https://bible.helloao.org) y **escriben los archivos con los
nombres de libro exactos** que la app espera (incluido el detalle de los
Evangelios: `S. Mateo`, `S.Juan`, etc.), así que no tienes que pelearte con eso.

- `fetch_bible.ps1` usa por defecto **Reina-Valera Gómez** (`spa_rvg`, libre).
  Para otra: `... fetch_bible.ps1 -translation spa_r09` (Reina-Valera 1909).
- ¿No usas Windows? Los scripts son cortos; replicar su lógica en bash/Python es
  trivial (es bajar JSON y reescribirlo). PRs bienvenidos.

---

## 🛠️ Forma manual (si traes tu propio texto)

### `rv1960.json`
Mapa `{ "Libro": { "capítulo": { "versículo": "texto" } } }`:

```json
{
  "Génesis": { "1": { "1": "En el principio creó Dios...", "2": "..." } },
  "S. Mateo": { "1": { "1": "..." } }
}
```

⚠️ Las **claves de libro deben coincidir exactamente** con el campo `jsonKey`
de [`lib/data/books.dart`](../../lib/data/books.dart). Ojo con los Evangelios:
`S. Mateo`, `S. Marcos`, `S. Lucas`, `S.Juan` (este último sin espacio).

### `headings.json`
Mapa `{ "bookId": { "capítulo": { "versículo": "título" } } }`, donde `bookId`
es el id **1–66** de `books.dart`:

```json
{ "1": { "1": { "1": "La creación" } } }
```

> Sin `rv1960.json` la app compila y abre, pero no mostrará texto.

---

## 📩 ¿Lo quieres directo, sin complicarte?

Escríbeme y con gusto te paso el paquete de datos listo:
**Kevin Carrera — kevin.ccdo@gmail.com**
