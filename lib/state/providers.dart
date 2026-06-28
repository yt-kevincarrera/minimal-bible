import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backup.dart';
import '../data/bible_repository.dart';
import '../data/books.dart';
import '../data/database.dart';
import '../data/models.dart';

final databaseProvider = FutureProvider<BibleDatabase>((ref) async {
  final db = BibleDatabase();
  await db.open();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = FutureProvider<BibleRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return BibleRepository(db.db);
});

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final prefs = await ref.read(sharedPrefsProvider.future);
  return BackupService(db.db, prefs);
});

final booksProvider = FutureProvider<List<Book>>((ref) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.allBooks();
});

class ChapterRef {
  final int bookId;
  final int chapter;
  const ChapterRef(this.bookId, this.chapter);

  @override
  bool operator ==(Object other) =>
      other is ChapterRef && other.bookId == bookId && other.chapter == chapter;

  @override
  int get hashCode => Object.hash(bookId, chapter);
}

final chapterProvider = FutureProvider.family<List<Verse>, ChapterRef>((
  ref,
  c,
) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.chapter(c.bookId, c.chapter);
});

final bookProvider = FutureProvider.family<Book, int>((ref, id) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.book(id);
});

final chapterHeadingsProvider =
    FutureProvider.family<Map<int, String>, ChapterRef>((ref, c) async {
      final repo = await ref.watch(repositoryProvider.future);
      return repo.headingsFor(c.bookId, c.chapter);
    });

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Alcance de la búsqueda: toda la Biblia, solo Antiguo o solo Nuevo.
enum SearchScope { all, oldT, newT }

final searchScopeProvider = StateProvider<SearchScope>((ref) => SearchScope.all);

/// Si true, busca la frase exacta en vez de todas las palabras sueltas.
final searchPhraseProvider = StateProvider<bool>((ref) => false);

final searchResultsProvider = FutureProvider<List<SearchHit>>((ref) async {
  final q = ref.watch(searchQueryProvider);
  if (q.trim().length < 2) return const [];
  final scope = ref.watch(searchScopeProvider);
  final phrase = ref.watch(searchPhraseProvider);
  final repo = await ref.watch(repositoryProvider.future);
  final testament = switch (scope) {
    SearchScope.all => null,
    SearchScope.oldT => testamentOld,
    SearchScope.newT => testamentNew,
  };
  return repo.search(q, testament: testament, phrase: phrase);
});

final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

/// Lectura: último libro/capítulo, capítulos leídos por libro y días leídos.
class ReadingProgress {
  final int? lastBookId;
  final Map<int, int> chapters; // bookId -> último capítulo leído
  final Map<int, Set<int>> read; // bookId -> capítulos leídos
  final Set<String> days; // fechas "YYYY-MM-DD" con lectura
  final Map<String, int> visits; // "bookId:chapter" -> veces abierto
  final Map<int, String> completed; // bookId -> fecha en que se completó

  const ReadingProgress({
    this.lastBookId,
    this.chapters = const {},
    this.read = const {},
    this.days = const {},
    this.visits = const {},
    this.completed = const {},
  });

  int? get lastChapter => lastBookId == null ? null : chapters[lastBookId];

  int? chapterOf(int bookId) => chapters[bookId];

  int readCountFor(int bookId) => read[bookId]?.length ?? 0;

  int get totalRead => read.values.fold(0, (a, s) => a + s.length);

  /// Veces totales leídas por libro (contando relecturas).
  int visitsForBook(int bookId) {
    var n = 0;
    final prefix = '$bookId:';
    for (final e in visits.entries) {
      if (e.key.startsWith(prefix)) n += e.value;
    }
    return n;
  }
}

class ReadingProgressNotifier extends Notifier<ReadingProgress> {
  static const _lastBookKey = 'last_book';
  static const _chaptersKey = 'book_chapters';
  static const _readKey = 'read_chapters';
  static const _daysKey = 'read_days';
  static const _visitsKey = 'visit_counts';
  static const _completedKey = 'book_completed';

  @override
  ReadingProgress build() => const ReadingProgress();

  Future<void> load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final lastBook = prefs.getInt(_lastBookKey);

    final map = <int, int>{};
    final rawChapters = prefs.getString(_chaptersKey);
    if (rawChapters != null) {
      (json.decode(rawChapters) as Map<String, dynamic>).forEach(
        (k, v) => map[int.parse(k)] = v as int,
      );
    }

    final read = <int, Set<int>>{};
    final rawRead = prefs.getString(_readKey);
    if (rawRead != null) {
      (json.decode(rawRead) as Map<String, dynamic>).forEach((k, v) {
        read[int.parse(k)] = {for (final c in (v as List)) c as int};
      });
    }

    final days = (prefs.getStringList(_daysKey) ?? const []).toSet();

    final visits = <String, int>{};
    final rawVisits = prefs.getString(_visitsKey);
    if (rawVisits != null) {
      (json.decode(rawVisits) as Map<String, dynamic>).forEach(
        (k, v) => visits[k] = v as int,
      );
    }

    final completed = <int, String>{};
    final rawCompleted = prefs.getString(_completedKey);
    if (rawCompleted != null) {
      (json.decode(rawCompleted) as Map<String, dynamic>).forEach(
        (k, v) => completed[int.parse(k)] = v as String,
      );
    }

    state = ReadingProgress(
      lastBookId: lastBook,
      chapters: map,
      read: read,
      days: days,
      visits: visits,
      completed: completed,
    );
  }

  Future<void> visit(int bookId, int chapter, {int? totalChapters}) async {
    final today = _today();

    final chapters = Map<int, int>.from(state.chapters)..[bookId] = chapter;
    final read = {
      for (final e in state.read.entries) e.key: {...e.value},
    };
    (read[bookId] ??= {}).add(chapter);
    final days = {...state.days, today};
    final visits = Map<String, int>.from(state.visits);
    final vk = '$bookId:$chapter';
    visits[vk] = (visits[vk] ?? 0) + 1;

    // Snapshot: primera vez que se completa el libro.
    final completed = Map<int, String>.from(state.completed);
    if (totalChapters != null &&
        read[bookId]!.length >= totalChapters &&
        !completed.containsKey(bookId)) {
      completed[bookId] = today;
    }

    state = ReadingProgress(
      lastBookId: bookId,
      chapters: chapters,
      read: read,
      days: days,
      visits: visits,
      completed: completed,
    );

    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setInt(_lastBookKey, bookId);
    await prefs.setString(
      _chaptersKey,
      json.encode(chapters.map((k, v) => MapEntry('$k', v))),
    );
    await prefs.setString(
      _readKey,
      json.encode(read.map((k, v) => MapEntry('$k', v.toList()))),
    );
    await prefs.setStringList(_daysKey, days.toList());
    await prefs.setString(_visitsKey, json.encode(visits));
    await prefs.setString(
      _completedKey,
      json.encode(completed.map((k, v) => MapEntry('$k', v))),
    );
  }

  /// Reinicia todas las estadísticas de lectura.
  Future<void> reset() async {
    state = const ReadingProgress();
    final prefs = await ref.read(sharedPrefsProvider.future);
    for (final k in [
      _lastBookKey,
      _chaptersKey,
      _readKey,
      _daysKey,
      _visitsKey,
      _completedKey,
      'reading_seconds',
    ]) {
      await prefs.remove(k);
    }
  }

  String _today() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }
}

final readingProgressProvider =
    NotifierProvider<ReadingProgressNotifier, ReadingProgress>(
      ReadingProgressNotifier.new,
    );

// ---- Colecciones / playlists ----------------------------------------------

final collectionsProvider = FutureProvider<List<Collection>>((ref) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.collections();
});

final collectionVersesProvider = FutureProvider.family<List<SavedVerse>, int>((
  ref,
  id,
) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.versesIn(id);
});

/// Versículos del capítulo que ya están en Favoritos (para el toggle).
final chapterFavoritesProvider = FutureProvider.family<Set<int>, ChapterRef>((
  ref,
  c,
) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.favoriteVerseIdsForChapter(c.bookId, c.chapter);
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final v = prefs.getString(_key);
    state = switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString(_key, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> toggle() async {
    final next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await setMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class FontScaleNotifier extends Notifier<double> {
  static const _key = 'font_scale';
  static const minScale = 0.8;
  static const maxScale = 1.8;

  @override
  double build() => 1.0;

  Future<void> load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final v = prefs.getDouble(_key);
    if (v != null) state = v.clamp(minScale, maxScale);
  }

  Future<void> set(double v) async {
    final clamped = v.clamp(minScale, maxScale);
    if (clamped == state) return;
    state = clamped;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setDouble(_key, clamped);
  }
}

final fontScaleProvider = NotifierProvider<FontScaleNotifier, double>(
  FontScaleNotifier.new,
);

/// Mantener la pantalla encendida mientras se lee.
class KeepAwakeNotifier extends Notifier<bool> {
  static const _key = 'keep_awake';

  @override
  bool build() => false;

  Future<void> load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool v) async {
    state = v;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(_key, v);
  }
}

final keepAwakeProvider = NotifierProvider<KeepAwakeNotifier, bool>(
  KeepAwakeNotifier.new,
);

// ---- Estadísticas ----------------------------------------------------------

final readingSecondsProvider = FutureProvider<int>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getInt('reading_seconds') ?? 0;
});

final savedVerseCountProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.savedVerseCount();
});

class AccentNotifier extends Notifier<int> {
  static const _key = 'accent_index';

  @override
  int build() => 0;

  Future<void> load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = prefs.getInt(_key) ?? 0;
  }

  Future<void> set(int index) async {
    if (index == state) return;
    state = index;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setInt(_key, index);
  }
}

final accentProvider = NotifierProvider<AccentNotifier, int>(
  AccentNotifier.new,
);

/// Última pestaña del home (0 = Antiguo, 1 = Nuevo).
class TabIndexNotifier extends Notifier<int> {
  static const _key = 'home_tab';

  @override
  int build() => 0;

  Future<void> load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    state = (prefs.getInt(_key) ?? 0).clamp(0, 1);
  }

  Future<void> set(int index) async {
    if (index == state) return;
    state = index;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setInt(_key, index);
  }
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(
  TabIndexNotifier.new,
);

/// Posición de scroll por capítulo ("bookId:chapter" -> offset en píxeles).
class ScrollStore extends Notifier<Map<String, double>> {
  static const _key = 'scroll_offsets';

  @override
  Map<String, double> build() => {};

  Future<void> load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final decoded = json.decode(raw) as Map<String, dynamic>;
    state = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  double? offsetFor(int bookId, int chapter) => state['$bookId:$chapter'];

  Future<void> save(int bookId, int chapter, double offset) async {
    final map = Map<String, double>.from(state);
    if (offset <= 1) {
      map.remove('$bookId:$chapter');
    } else {
      map['$bookId:$chapter'] = offset;
    }
    state = map;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setString(_key, json.encode(map));
  }
}

final scrollStoreProvider = NotifierProvider<ScrollStore, Map<String, double>>(
  ScrollStore.new,
);

// ---- Resaltado de versículos por color ------------------------------------

/// Mapa verseId -> índice de color, para el capítulo dado.
final chapterHighlightsProvider =
    FutureProvider.family<Map<int, int>, ChapterRef>((ref, c) async {
      final repo = await ref.watch(repositoryProvider.future);
      return repo.highlightsForChapter(c.bookId, c.chapter);
    });

/// Conteo de versículos por color: índice de color -> cantidad.
final highlightCountsProvider = FutureProvider<Map<int, int>>((ref) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.highlightCounts();
});

final versesByColorProvider = FutureProvider.family<List<SavedVerse>, int>((
  ref,
  colorIndex,
) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.versesByColor(colorIndex);
});
