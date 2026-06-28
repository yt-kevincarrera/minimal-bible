import 'package:sqflite/sqflite.dart';

import 'models.dart';

class BibleRepository {
  BibleRepository(this._db);
  final Database _db;

  Future<List<Book>> allBooks() async {
    final rows = await _db.query('books', orderBy: 'id ASC');
    return rows.map(Book.fromRow).toList(growable: false);
  }

  Future<Book> book(int bookId) async {
    final rows = await _db.query('books', where: 'id = ?', whereArgs: [bookId]);
    return Book.fromRow(rows.first);
  }

  /// Títulos de sección por capítulo: verso -> título que lo introduce.
  Future<Map<int, String>> headingsFor(int bookId, int chapter) async {
    final rows = await _db.query(
      'headings',
      columns: ['verse', 'title'],
      where: 'book_id = ? AND chapter = ?',
      whereArgs: [bookId, chapter],
    );
    return {for (final r in rows) r['verse'] as int: r['title'] as String};
  }

  Future<List<Verse>> chapter(int bookId, int chapter) async {
    final rows = await _db.query(
      'verses',
      where: 'book_id = ? AND chapter = ?',
      whereArgs: [bookId, chapter],
      orderBy: 'verse ASC',
    );
    return rows.map(Verse.fromRow).toList(growable: false);
  }

  /// Búsqueda de texto completo. Filtros opcionales:
  /// - [testament]: 'OT' / 'NT' para acotar al Antiguo o Nuevo Testamento.
  /// - [phrase]: true busca la frase exacta; false (por defecto) todas las
  ///   palabras en cualquier orden (con prefijo, como hasta ahora).
  Future<List<SearchHit>> search(
    String query, {
    int limit = 200,
    String? testament,
    bool phrase = false,
  }) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return const [];
    final ftsQuery = phrase ? _toFtsPhrase(cleaned) : _toFtsQuery(cleaned);

    final args = <Object?>[ftsQuery];
    var testamentFilter = '';
    if (testament != null) {
      testamentFilter = 'AND b.testament = ?';
      args.add(testament);
    }
    args.add(limit);

    final rows = await _db.rawQuery(
      '''
      SELECT v.book_id, v.chapter, v.verse, v.text,
             b.name AS book_name, b.abbr AS book_abbr,
             snippet(verses_fts, 0, '<b>', '</b>', '…', 12) AS snippet
      FROM verses_fts
      JOIN verses v ON v.id = verses_fts.rowid
      JOIN books  b ON b.id = v.book_id
      WHERE verses_fts MATCH ? $testamentFilter
      ORDER BY v.book_id, v.chapter, v.verse
      LIMIT ?
    ''',
      args,
    );

    return rows
        .map(
          (r) => SearchHit(
            bookId: r['book_id'] as int,
            bookName: r['book_name'] as String,
            bookAbbr: r['book_abbr'] as String,
            chapter: r['chapter'] as int,
            verse: r['verse'] as int,
            text: r['text'] as String,
            snippet: r['snippet'] as String,
          ),
        )
        .toList(growable: false);
  }

  String _toFtsQuery(String input) {
    final tokens = input
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '""';
    return tokens.map((t) => '"$t"*').join(' ');
  }

  /// Frase exacta: las palabras deben aparecer juntas y en orden.
  String _toFtsPhrase(String input) {
    final tokens = input
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '""';
    return '"${tokens.join(' ')}"';
  }

  /// Carga versículos concretos por referencia ([[bookId, chapter, verse], …]),
  /// conservando el orden de entrada. Para los índices de temas.
  Future<List<SavedVerse>> versesByRefs(List<List<int>> refs) async {
    if (refs.isEmpty) return const [];
    final clause = List.filled(
      refs.length,
      '(v.book_id = ? AND v.chapter = ? AND v.verse = ?)',
    ).join(' OR ');
    final args = <Object?>[for (final r in refs) ...r];
    final rows = await _db.rawQuery('''
      SELECT v.id AS verse_id, v.book_id, v.chapter, v.verse, v.text,
             b.name AS book_name, b.abbr AS book_abbr, 0 AS added_at
      FROM verses v
      JOIN books b ON b.id = v.book_id
      WHERE $clause
    ''', args);
    final byKey = {
      for (final r in rows)
        '${r['book_id']}:${r['chapter']}:${r['verse']}': SavedVerse.fromRow(r),
    };
    final out = <SavedVerse>[];
    for (final r in refs) {
      final v = byKey['${r[0]}:${r[1]}:${r[2]}'];
      if (v != null) out.add(v);
    }
    return out;
  }

  // ---- Colecciones / playlists --------------------------------------------

  Future<List<Collection>> collections() async {
    final rows = await _db.rawQuery('''
      SELECT c.id, c.name, c.is_favorites,
        (SELECT COUNT(*) FROM collection_verses cv
         WHERE cv.collection_id = c.id) AS verse_count
      FROM collections c
      ORDER BY c.is_favorites DESC, c.position ASC, c.id ASC
    ''');
    return rows.map(Collection.fromRow).toList(growable: false);
  }

  Future<int> favoritesId() async {
    final rows = await _db.query(
      'collections',
      columns: ['id'],
      where: 'is_favorites = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return _db.insert('collections', {
      'name': 'Favoritos',
      'is_favorites': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': 0,
    });
  }

  Future<int> createCollection(String name) async {
    final maxPos =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(MAX(position), 0) FROM collections',
          ),
        ) ??
        0;
    return _db.insert('collections', {
      'name': name.trim(),
      'is_favorites': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': maxPos + 1,
    });
  }

  Future<void> renameCollection(int id, String name) => _db.update(
    'collections',
    {'name': name.trim()},
    where: 'id = ? AND is_favorites = 0',
    whereArgs: [id],
  );

  Future<void> deleteCollection(int id) async {
    await _db.delete(
      'collection_verses',
      where: 'collection_id = ?',
      whereArgs: [id],
    );
    await _db.delete(
      'collections',
      where: 'id = ? AND is_favorites = 0',
      whereArgs: [id],
    );
  }

  Future<void> addVersesToCollection(
    int collectionId,
    List<int> verseIds,
  ) async {
    if (verseIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final vid in verseIds) {
      batch.rawInsert(
        'INSERT OR IGNORE INTO collection_verses(collection_id, verse_id, added_at) '
        'VALUES (?, ?, ?)',
        [collectionId, vid, now],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Versículos de [bookId]/[chapter] que ya están en Favoritos.
  Future<Set<int>> favoriteVerseIdsForChapter(int bookId, int chapter) async {
    final rows = await _db.rawQuery(
      '''
      SELECT cv.verse_id
      FROM collection_verses cv
      JOIN collections c ON c.id = cv.collection_id AND c.is_favorites = 1
      JOIN verses v ON v.id = cv.verse_id
      WHERE v.book_id = ? AND v.chapter = ?
    ''',
      [bookId, chapter],
    );
    return {for (final r in rows) r['verse_id'] as int};
  }

  Future<void> removeVersesFromCollection(
    int collectionId,
    List<int> verseIds,
  ) async {
    if (verseIds.isEmpty) return;
    final ph = List.filled(verseIds.length, '?').join(',');
    await _db.rawDelete(
      'DELETE FROM collection_verses WHERE collection_id = ? AND verse_id IN ($ph)',
      [collectionId, ...verseIds],
    );
  }

  Future<void> removeVerseFromCollection(int collectionId, int verseId) =>
      _db.delete(
        'collection_verses',
        where: 'collection_id = ? AND verse_id = ?',
        whereArgs: [collectionId, verseId],
      );

  Future<List<SavedVerse>> versesIn(int collectionId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT v.id AS verse_id, v.book_id, v.chapter, v.verse, v.text,
             b.name AS book_name, b.abbr AS book_abbr, cv.added_at AS added_at
      FROM collection_verses cv
      JOIN verses v ON v.id = cv.verse_id
      JOIN books  b ON b.id = v.book_id
      WHERE cv.collection_id = ?
      ORDER BY cv.added_at DESC, v.book_id, v.chapter, v.verse
    ''',
      [collectionId],
    );
    return rows.map(SavedVerse.fromRow).toList(growable: false);
  }

  // ---- Resaltado por color -------------------------------------------------

  Future<Map<int, int>> highlightsForChapter(int bookId, int chapter) async {
    final rows = await _db.rawQuery(
      '''
      SELECT vh.verse_id, vh.color
      FROM verse_highlights vh
      JOIN verses v ON v.id = vh.verse_id
      WHERE v.book_id = ? AND v.chapter = ?
    ''',
      [bookId, chapter],
    );
    return {for (final r in rows) r['verse_id'] as int: r['color'] as int};
  }

  Future<void> setHighlight(List<int> verseIds, int color) async {
    if (verseIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final vid in verseIds) {
      batch.insert('verse_highlights', {
        'verse_id': vid,
        'color': color,
        'added_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeHighlights(List<int> verseIds) async {
    if (verseIds.isEmpty) return;
    final placeholders = List.filled(verseIds.length, '?').join(',');
    await _db.rawDelete(
      'DELETE FROM verse_highlights WHERE verse_id IN ($placeholders)',
      verseIds,
    );
  }

  /// Borra todos los datos del usuario: bibliotecas, favoritos y resaltados.
  /// Re-crea la biblioteca de Favoritos vacía.
  Future<void> wipeUserData() async {
    await _db.delete('collection_verses');
    await _db.delete('collections');
    await _db.delete('verse_highlights');
    await _db.insert('collections', {
      'name': 'Favoritos',
      'is_favorites': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': 0,
    });
  }

  Future<int> savedVerseCount() async {
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(DISTINCT verse_id) FROM collection_verses',
          ),
        ) ??
        0;
  }

  Future<Map<int, int>> highlightCounts() async {
    final rows = await _db.rawQuery(
      'SELECT color, COUNT(*) AS n FROM verse_highlights GROUP BY color',
    );
    return {for (final r in rows) r['color'] as int: r['n'] as int};
  }

  Future<List<SavedVerse>> versesByColor(int color) async {
    final rows = await _db.rawQuery(
      '''
      SELECT v.id AS verse_id, v.book_id, v.chapter, v.verse, v.text,
             b.name AS book_name, b.abbr AS book_abbr, vh.added_at AS added_at
      FROM verse_highlights vh
      JOIN verses v ON v.id = vh.verse_id
      JOIN books  b ON b.id = v.book_id
      WHERE vh.color = ?
      ORDER BY vh.added_at DESC, v.book_id, v.chapter, v.verse
    ''',
      [color],
    );
    return rows.map(SavedVerse.fromRow).toList(growable: false);
  }
}
