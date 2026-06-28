import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Exporta/importa los datos personales (playlists, favoritos, colores,
/// progreso y ajustes) en un JSON portable. Los versículos se guardan por
/// referencia (libro/capítulo/versículo), no por id interno, para que el
/// respaldo sea estable entre instalaciones.
class BackupService {
  BackupService(this._db, this._prefs);
  final Database _db;
  final SharedPreferences _prefs;

  static const _prefKeys = [
    'theme_mode',
    'accent_index',
    'font_scale',
    'line_height',
    'reader_layout',
    'last_book',
    'book_chapters',
    'read_chapters',
    'read_days',
    'visit_counts',
    'book_completed',
    'reading_seconds',
    'keep_awake',
    'home_tab',
  ];

  Future<String> export() async {
    final collections = await _db.rawQuery('''
      SELECT c.id, c.name, c.is_favorites FROM collections c
      ORDER BY c.is_favorites DESC, c.position ASC, c.id ASC
    ''');

    final outCollections = <Map<String, dynamic>>[];
    for (final c in collections) {
      final id = c['id'] as int;
      final refs = await _db.rawQuery(
        '''
        SELECT v.book_id, v.chapter, v.verse
        FROM collection_verses cv
        JOIN verses v ON v.id = cv.verse_id
        WHERE cv.collection_id = ?
        ORDER BY v.book_id, v.chapter, v.verse
      ''',
        [id],
      );
      outCollections.add({
        'name': c['name'],
        'isFavorites': (c['is_favorites'] as int) == 1,
        'verses': refs
            .map((r) => [r['book_id'], r['chapter'], r['verse']])
            .toList(),
      });
    }

    final highlights = await _db.rawQuery('''
      SELECT v.book_id, v.chapter, v.verse, vh.color
      FROM verse_highlights vh
      JOIN verses v ON v.id = vh.verse_id
    ''');

    final prefs = <String, dynamic>{};
    for (final k in _prefKeys) {
      final v = _prefs.get(k);
      if (v != null) prefs[k] = v;
    }

    return json.encode({
      'app': 'minimal_bible',
      'version': 1,
      'collections': outCollections,
      'highlights': highlights
          .map((r) => [r['book_id'], r['chapter'], r['verse'], r['color']])
          .toList(),
      'prefs': prefs,
    });
  }

  /// Importa fusionando con lo existente. Devuelve un resumen para el usuario.
  Future<String> import(String raw) async {
    final data = json.decode(raw) as Map<String, dynamic>;
    if (data['app'] != 'minimal_bible') {
      throw const FormatException('Archivo no reconocido');
    }

    var addedVerses = 0;
    var addedHighlights = 0;

    final now = DateTime.now().millisecondsSinceEpoch;

    Future<int?> verseId(List ref) async {
      final rows = await _db.query(
        'verses',
        columns: ['id'],
        where: 'book_id = ? AND chapter = ? AND verse = ?',
        whereArgs: [ref[0], ref[1], ref[2]],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first['id'] as int;
    }

    // Colecciones
    for (final c in (data['collections'] as List? ?? [])) {
      final name = c['name'] as String;
      final isFav = c['isFavorites'] == true;
      int collectionId;
      if (isFav) {
        final fav = await _db.query(
          'collections',
          columns: ['id'],
          where: 'is_favorites = 1',
          limit: 1,
        );
        collectionId = fav.isNotEmpty
            ? fav.first['id'] as int
            : await _db.insert('collections', {
                'name': 'Favoritos',
                'is_favorites': 1,
                'created_at': now,
                'position': 0,
              });
      } else {
        final existing = await _db.query(
          'collections',
          columns: ['id'],
          where: 'name = ? AND is_favorites = 0',
          whereArgs: [name],
          limit: 1,
        );
        collectionId = existing.isNotEmpty
            ? existing.first['id'] as int
            : await _db.insert('collections', {
                'name': name,
                'is_favorites': 0,
                'created_at': now,
                'position': now,
              });
      }
      for (final ref in (c['verses'] as List? ?? [])) {
        final vid = await verseId(ref as List);
        if (vid == null) continue;
        final n = await _db.rawInsert(
          'INSERT OR IGNORE INTO collection_verses(collection_id, verse_id, added_at) '
          'VALUES (?, ?, ?)',
          [collectionId, vid, now],
        );
        if (n > 0) addedVerses++;
      }
    }

    // Resaltados
    for (final h in (data['highlights'] as List? ?? [])) {
      final list = h as List;
      final vid = await verseId(list.sublist(0, 3));
      if (vid == null) continue;
      await _db.insert('verse_highlights', {
        'verse_id': vid,
        'color': list[3],
        'added_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      addedHighlights++;
    }

    // Preferencias
    final prefs = data['prefs'] as Map<String, dynamic>? ?? {};
    for (final entry in prefs.entries) {
      final v = entry.value;
      if (v is bool) {
        await _prefs.setBool(entry.key, v);
      } else if (v is int) {
        await _prefs.setInt(entry.key, v);
      } else if (v is double) {
        await _prefs.setDouble(entry.key, v);
      } else if (v is String) {
        await _prefs.setString(entry.key, v);
      } else if (v is List) {
        await _prefs.setStringList(
          entry.key,
          v.map((e) => e.toString()).toList(),
        );
      }
    }

    return 'Importado: $addedVerses versículos en listas, '
        '$addedHighlights resaltados.';
  }
}
