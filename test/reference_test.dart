import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_bible/data/books.dart';
import 'package:minimal_bible/data/models.dart';
import 'package:minimal_bible/data/reference.dart';

/// Construye la lista de libros (como vendría de la BD) a partir de los datos
/// canónicos, con un conteo de capítulos real para los libros que se prueban.
List<Book> _books() {
  const chapters = <int, int>{
    33: 7, // Miqueas
    43: 21, // Juan
    46: 16, // 1 Corintios
    62: 5, // 1 Juan
    30: 9, // Amós
    19: 150, // Salmos
  };
  return [
    for (final b in canonicalBooks)
      Book(
        id: b.id,
        name: b.name,
        abbr: b.abbr,
        testament: b.testament,
        chapterCount: chapters[b.id] ?? 1,
      ),
  ];
}

void main() {
  final books = _books();

  Reference? parse(String q) => parseReference(q, books);

  group('cita con capítulo y verso', () {
    test('"Jn 3:16" → Juan 3:16', () {
      final r = parse('Jn 3:16')!;
      expect(r.book.name, 'Juan');
      expect(r.chapter, 3);
      expect(r.verse, 16);
    });

    test('"Juan 3" → Juan 3 sin verso', () {
      final r = parse('Juan 3')!;
      expect(r.book.name, 'Juan');
      expect(r.chapter, 3);
      expect(r.verse, isNull);
    });

    test('"1 Co 13:4" → 1 Corintios 13:4', () {
      final r = parse('1 Co 13:4')!;
      expect(r.book.name, '1 Corintios');
      expect(r.chapter, 13);
      expect(r.verse, 4);
    });

    test('capítulo fuera de rango → null', () {
      expect(parse('Jn 99'), isNull);
    });
  });

  group('solo libro → vista de capítulos', () {
    test('"Jn" → Juan, sin capítulo', () {
      final r = parse('Jn')!;
      expect(r.book.name, 'Juan');
      expect(r.isBookOnly, isTrue);
    });

    test('"miq" → Miqueas', () {
      expect(parse('miq')!.book.name, 'Miqueas');
    });

    test('"mq" → Miqueas', () {
      expect(parse('mq')!.book.name, 'Miqueas');
    });

    test('nombre completo "Miqueas" → Miqueas', () {
      expect(parse('Miqueas')!.book.name, 'Miqueas');
    });

    test('"1 Jn" → 1 Juan (y no Juan)', () {
      expect(parse('1 Jn')!.book.name, '1 Juan');
    });
  });

  group('no debe ensuciar la búsqueda normal', () {
    test('"mi" no es una cita (Miqueas usa Miq, no Mi)', () {
      expect(parse('mi'), isNull);
    });

    test('palabra normal "amor" → null', () {
      expect(parse('amor'), isNull);
    });

    test('prefijo de nombre sin número no dispara ("jua") → null', () {
      expect(parse('jua'), isNull);
    });

    test('vacío → null', () {
      expect(parse(''), isNull);
      expect(parse('   '), isNull);
    });
  });
}
