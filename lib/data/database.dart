import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'books.dart';

class BibleDatabase {
  static const _dbVersion = 4;
  static const _dbFile = 'minimal_bible.db';

  late final Database _db;
  Database get db => _db;

  Future<void> open() async {
    String path;
    if (kIsWeb) {
      // El shared worker (sqflite_sw.js) suele devolver "unsupported result
      // null(null)" si no carga; la variante sin worker corre en el hilo
      // principal y es mucho más fiable.
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      path = _dbFile;
    } else {
      // FFI con SQLite propio (sqlite3_flutter_libs) en TODAS las plataformas
      // nativas: el SQLite del sistema Android no incluye FTS5, así que
      // empaquetamos uno que sí lo trae.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await getApplicationSupportDirectory();
      path = p.join(dir.path, _dbFile);
    }

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async => _create(db),
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _createCollections(db);
        if (oldV < 3) {
          await _createHeadings(db);
          await _seedHeadings(db);
        }
        if (oldV < 4) {
          await _createHighlights(db);
          // Re-siembra los títulos con la codificación UTF-8 corregida
          // (versiones previas pudieron guardar acentos con mojibake).
          await _seedHeadings(db);
        }
      },
    );

    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM verses'),
    );
    if (count == null || count == 0) {
      await _seedFromAsset(_db);
    }

    // Auto-reparable: si los títulos aún no se sembraron (p. ej. el asset
    // llegó después), reintenta al abrir.
    final hCount = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM headings'),
    );
    if (hCount == null || hCount == 0) {
      await _seedHeadings(_db);
    }
  }

  Future<void> _create(Database db) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        abbr TEXT NOT NULL,
        testament TEXT NOT NULL,
        chapter_count INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE verses (
        id INTEGER PRIMARY KEY,
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL,
        UNIQUE(book_id, chapter, verse)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_verses_loc ON verses(book_id, chapter, verse)',
    );
    await db.execute('''
      CREATE VIRTUAL TABLE verses_fts USING fts5(
        text,
        content='verses',
        content_rowid='id',
        tokenize='unicode61 remove_diacritics 2'
      )
    ''');
    await db.execute('''
      CREATE TRIGGER verses_ai AFTER INSERT ON verses BEGIN
        INSERT INTO verses_fts(rowid, text) VALUES (new.id, new.text);
      END
    ''');
    await _createCollections(db);
    await _createHeadings(db);
    await _seedHeadings(db);
    await _createHighlights(db);
  }

  Future<void> _createHighlights(Database db) async {
    await db.execute('''
      CREATE TABLE verse_highlights (
        verse_id INTEGER PRIMARY KEY,
        color INTEGER NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_vh_color ON verse_highlights(color)');
  }

  Future<void> _createHeadings(Database db) async {
    await db.execute('''
      CREATE TABLE headings (
        book_id INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        title TEXT NOT NULL,
        PRIMARY KEY (book_id, chapter, verse)
      )
    ''');
  }

  Future<void> _seedHeadings(Database db) async {
    String raw;
    try {
      raw = await rootBundle.loadString('assets/data/headings.json');
    } catch (_) {
      return; // asset opcional; si no está, simplemente no hay títulos
    }
    final data = json.decode(raw) as Map<String, dynamic>;
    await db.transaction((txn) async {
      final batch = txn.batch();
      data.forEach((bookId, chapters) {
        (chapters as Map).forEach((chap, verses) {
          (verses as Map).forEach((verse, title) {
            batch.insert('headings', {
              'book_id': int.parse(bookId),
              'chapter': int.parse(chap as String),
              'verse': int.parse(verse as String),
              'title': title as String,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          });
        });
      });
      await batch.commit(noResult: true);
    });
  }

  Future<void> _createCollections(Database db) async {
    await db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_favorites INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE collection_verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER NOT NULL,
        verse_id INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        UNIQUE(collection_id, verse_id),
        FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_cv_coll ON collection_verses(collection_id)',
    );
    await db.insert('collections', {
      'name': 'Favoritos',
      'is_favorites': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'position': 0,
    });
  }

  Future<void> _seedFromAsset(Database db) async {
    final raw = await rootBundle.loadString('assets/data/rv1960.json');
    final Map<String, dynamic> data = json.decode(raw) as Map<String, dynamic>;

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final book in canonicalBooks) {
        final raw = data[book.jsonKey];
        if (raw is! Map) {
          if (kDebugMode) {
            debugPrint('Missing book JSON: ${book.jsonKey}');
          }
          continue;
        }
        final chapters = raw.cast<String, dynamic>();
        final chapterCount = chapters.length;
        batch.insert('books', {
          'id': book.id,
          'name': book.name,
          'abbr': book.abbr,
          'testament': book.testament,
          'chapter_count': chapterCount,
        });

        final chapterNumbers =
            chapters.keys.map(int.tryParse).whereType<int>().toList()..sort();

        for (final c in chapterNumbers) {
          final verses = (chapters['$c'] as Map).cast<String, dynamic>();
          final verseNumbers =
              verses.keys.map(int.tryParse).whereType<int>().toList()..sort();
          for (final v in verseNumbers) {
            final text = (verses['$v'] as String).trim();
            batch.insert('verses', {
              'book_id': book.id,
              'chapter': c,
              'verse': v,
              'text': text,
            });
          }
        }
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> close() async => _db.close();
}
