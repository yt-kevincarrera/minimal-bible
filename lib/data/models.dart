class Book {
  final int id;
  final String name;
  final String abbr;
  final String testament;
  final int chapterCount;

  const Book({
    required this.id,
    required this.name,
    required this.abbr,
    required this.testament,
    required this.chapterCount,
  });

  factory Book.fromRow(Map<String, Object?> r) => Book(
    id: r['id'] as int,
    name: r['name'] as String,
    abbr: r['abbr'] as String,
    testament: r['testament'] as String,
    chapterCount: r['chapter_count'] as int,
  );
}

class Verse {
  final int id;
  final int bookId;
  final int chapter;
  final int verse;
  final String text;

  const Verse({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  factory Verse.fromRow(Map<String, Object?> r) => Verse(
    id: r['id'] as int,
    bookId: r['book_id'] as int,
    chapter: r['chapter'] as int,
    verse: r['verse'] as int,
    text: r['text'] as String,
  );
}

class SearchHit {
  final int bookId;
  final String bookName;
  final String bookAbbr;
  final int chapter;
  final int verse;
  final String text;
  final String snippet;

  const SearchHit({
    required this.bookId,
    required this.bookName,
    required this.bookAbbr,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.snippet,
  });

  String get reference => '$bookName $chapter:$verse';
}

class Collection {
  final int id;
  final String name;
  final bool isFavorites;
  final int verseCount;

  const Collection({
    required this.id,
    required this.name,
    required this.isFavorites,
    required this.verseCount,
  });

  factory Collection.fromRow(Map<String, Object?> r) => Collection(
    id: r['id'] as int,
    name: r['name'] as String,
    isFavorites: (r['is_favorites'] as int) == 1,
    verseCount: (r['verse_count'] as int?) ?? 0,
  );
}

class SavedVerse {
  final int verseId;
  final int bookId;
  final String bookName;
  final String bookAbbr;
  final int chapter;
  final int verse;
  final String text;
  final int
  addedAt; // marca de lote: versículos guardados juntos comparten esto

  const SavedVerse({
    required this.verseId,
    required this.bookId,
    required this.bookName,
    required this.bookAbbr,
    required this.chapter,
    required this.verse,
    required this.text,
    this.addedAt = 0,
  });

  factory SavedVerse.fromRow(Map<String, Object?> r) => SavedVerse(
    verseId: r['verse_id'] as int,
    bookId: r['book_id'] as int,
    bookName: r['book_name'] as String,
    bookAbbr: r['book_abbr'] as String,
    chapter: r['chapter'] as int,
    verse: r['verse'] as int,
    text: r['text'] as String,
    addedAt: (r['added_at'] as int?) ?? 0,
  );

  String get reference => '$bookName $chapter:$verse';
}

/// Grupo de versículos guardados/coloreados en una misma acción.
class VerseGroup {
  final List<SavedVerse> verses; // ordenados por libro/cap/verso
  const VerseGroup(this.verses);

  List<int> get verseIds => verses.map((v) => v.verseId).toList();

  /// Referencia compacta del grupo: "Juan 3:16-18" si es contiguo en un mismo
  /// capítulo, "Juan 3:16, 18, 20" si no, o un rango si abarca varios.
  String get reference {
    if (verses.length == 1) return verses.first.reference;
    final sameBook = verses.every((v) => v.bookId == verses.first.bookId);
    final sameChapter =
        sameBook && verses.every((v) => v.chapter == verses.first.chapter);
    if (sameChapter) {
      final nums = verses.map((v) => v.verse).toList()..sort();
      final contiguous = nums.last - nums.first == nums.length - 1;
      final b = verses.first;
      if (contiguous) {
        return '${b.bookName} ${b.chapter}:${nums.first}-${nums.last}';
      }
      return '${b.bookName} ${b.chapter}:${nums.join(', ')}';
    }
    final a = verses.first;
    final z = verses.last;
    return '${a.reference} – ${z.bookName} ${z.chapter}:${z.verse}';
  }
}

/// Agrupa versículos por lote (added_at). Conserva el orden de entrada
/// (lotes más recientes primero) y ordena cada grupo por ubicación.
List<VerseGroup> groupByBatch(List<SavedVerse> verses) {
  final byBatch = <int, List<SavedVerse>>{};
  final order = <int>[];
  for (final v in verses) {
    if (!byBatch.containsKey(v.addedAt)) order.add(v.addedAt);
    (byBatch[v.addedAt] ??= []).add(v);
  }
  return [
    for (final k in order)
      VerseGroup(
        byBatch[k]!..sort((a, b) {
          if (a.bookId != b.bookId) return a.bookId - b.bookId;
          if (a.chapter != b.chapter) return a.chapter - b.chapter;
          return a.verse - b.verse;
        }),
      ),
  ];
}
