import 'books.dart';
import 'models.dart';

/// Una referencia bíblica resuelta a partir de lo que escribe el usuario.
///
/// - [chapter] == null  → solo se reconoció el libro ("Jn"): llevar a la
///   pantalla de selección de capítulos.
/// - [chapter] != null, [verse] == null → "Juan 3": abrir el capítulo.
/// - [chapter] != null, [verse] != null → "Jn 3:16": abrir y resaltar el verso.
class Reference {
  final Book book;
  final int? chapter;
  final int? verse;

  const Reference({required this.book, this.chapter, this.verse});

  bool get isBookOnly => chapter == null;

  @override
  bool operator ==(Object other) =>
      other is Reference &&
      other.book.id == book.id &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(book.id, chapter, verse);
}

// Compiladas una vez: normRef se llama por cada libro y alias, y antes cada
// llamada recompilaba las seis expresiones.
final _reA = RegExp('[áàä]');
final _reE = RegExp('[éèë]');
final _reI = RegExp('[íìï]');
final _reO = RegExp('[óòö]');
final _reU = RegExp('[úùü]');
final _reNotAlnum = RegExp('[^a-z0-9]');

/// Normaliza para comparar referencias: minúsculas, sin tildes y sin nada que
/// no sea letra o dígito (así "1 Co", "1co" y "1 Co." son equivalentes).
String normRef(String s) => s
    .toLowerCase()
    .replaceAll(_reA, 'a')
    .replaceAll(_reE, 'e')
    .replaceAll(_reI, 'i')
    .replaceAll(_reO, 'o')
    .replaceAll(_reU, 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(_reNotAlnum, '');

/// Token normalizado -> id de libro, para nombres completos y alias. Se
/// construye una sola vez (al primer uso): antes se normalizaban los 66 nombres
/// y sus alias en cada intento de reconocer una cita, o sea en cada tecla que
/// se escribe en el buscador.
///
/// Se recorre en el mismo orden que antes y con `putIfAbsent`, así el primero
/// que reclama un token sigue ganando.
final Map<String, int> _bookIdByToken = () {
  final map = <String, int>{};
  for (final b in canonicalBooks) {
    map.putIfAbsent(normRef(b.name), () => b.id);
    for (final alias in bookGotoAliases[b.id] ?? const <String>[]) {
      map.putIfAbsent(normRef(alias), () => b.id);
    }
  }
  return map;
}();

/// Devuelve el id del libro cuyo nombre completo o alias coincide EXACTAMENTE
/// con [token] (ya normalizado). No usa coincidencia por prefijo, para no
/// disparar "ir a la cita" con palabras normales de búsqueda. Devuelve null si
/// no hay coincidencia exacta.
int? bookIdForToken(String token) =>
    token.isEmpty ? null : _bookIdByToken[token];

Book? _bookById(int id, List<Book> books) {
  for (final b in books) {
    if (b.id == id) return b;
  }
  return null;
}

final _reCitation = RegExp(
  r'^\s*([0-9]?\s*[^\d:]+?)\s+(\d+)(?::(\d+))?\s*$',
  unicode: true,
);

/// Nombre y abreviatura normalizados de cada libro de [books], en su orden.
/// Memorizado por identidad de la lista: `booksProvider` la mantiene estable,
/// así que normalizar los 66 libros pasa de ser por pulsación a una sola vez.
List<Book> _normCacheFor = const [];
List<(String, String, Book)> _normCache = const [];

List<(String, String, Book)> _normalizedBooks(List<Book> books) {
  if (identical(_normCacheFor, books)) return _normCache;
  _normCache = [
    for (final b in books) (normRef(b.name), normRef(b.abbr), b),
  ];
  _normCacheFor = books;
  return _normCache;
}

/// Interpreta lo que escribe el usuario como una referencia bíblica.
///
/// Reconoce "Jn 3:16", "Juan 3", "1 Co 13:4" (libro + capítulo [+ verso]) y
/// también solo el libro: "Jn", "Miqueas". Devuelve null si no parece una
/// referencia.
Reference? parseReference(String input, List<Book> books) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || books.isEmpty) return null;

  // Caso con número: "<libro> <cap>[:<verso>]".
  final m = _reCitation.firstMatch(trimmed);
  if (m != null) {
    final bookPart = normRef(m.group(1)!);
    final chapter = int.tryParse(m.group(2)!);
    final verse = m.group(3) == null ? null : int.tryParse(m.group(3)!);
    if (bookPart.isEmpty || chapter == null) return null;
    final book = _resolveBook(bookPart, books, allowPrefix: true);
    if (book == null) return null;
    if (chapter < 1 || chapter > book.chapterCount) return null;
    return Reference(book: book, chapter: chapter, verse: verse);
  }

  // Caso solo libro: coincidencia EXACTA con nombre o alias.
  final id = bookIdForToken(normRef(trimmed));
  if (id == null) return null;
  final book = _bookById(id, books);
  if (book == null) return null;
  return Reference(book: book, chapter: null, verse: null);
}

/// Resuelve el libro para el caso con capítulo. Como el número ya indica la
/// intención, aquí sí se admite coincidencia por prefijo del nombre o de la
/// abreviatura mostrada (p.ej. "Jua 3"), además de los alias exactos.
Book? _resolveBook(
  String token,
  List<Book> books, {
  required bool allowPrefix,
}) {
  final id = bookIdForToken(token);
  if (id != null) {
    final b = _bookById(id, books);
    if (b != null) return b;
  }
  Book? prefix;
  for (final (n, a, b) in _normalizedBooks(books)) {
    if (n == token || a == token) return b;
    if (allowPrefix &&
        prefix == null &&
        token.length >= 2 &&
        (n.startsWith(token) || a.startsWith(token))) {
      prefix = b;
    }
  }
  return allowPrefix ? prefix : null;
}
