import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_bible/data/models.dart';
import 'package:minimal_bible/state/providers.dart';

Topic _topic(String title, List<String> aliases) => Topic.fromJson({
  'title': title,
  'aliases': aliases,
  'refs': [
    [43, 3, 16],
  ],
});

void main() {
  final topics = [
    _topic('La parábola del sembrador', ['el sembrador', 'sembrador']),
    _topic('Los diez mandamientos', ['mandamientos', 'decálogo']),
    _topic('El fruto del Espíritu', ['fruto del espiritu']),
    _topic('Ansiedad', ['preocupación', 'afán', 'angustia']),
  ];

  group('normalización precalculada', () {
    test('guarda título y alias sin tildes ni signos', () {
      final t = _topic('El fruto del Espíritu', ['¡Fruto!']);
      expect(t.normKeys, ['el fruto del espiritu', 'fruto']);
    });

    test('las palabras vacías no cuentan como tokens', () {
      final t = _topic('Los diez mandamientos', const []);
      expect(t.tokens, {'diez', 'mandamientos'});
    });
  });

  group('matchTopics', () {
    test('encuentra por título, ignorando tildes', () {
      expect(matchTopics('ansiedad', topics).first.title, 'Ansiedad');
      expect(matchTopics('preocupacion', topics).first.title, 'Ansiedad');
      expect(matchTopics('afan', topics).first.title, 'Ansiedad');
    });

    test('encuentra por palabras sueltas y en otro orden', () {
      expect(
        matchTopics('sembrador parabola', topics).first.title,
        'La parábola del sembrador',
      );
    });

    test('la coincidencia exacta va primero', () {
      final hits = matchTopics('mandamientos', topics);
      expect(hits.first.title, 'Los diez mandamientos');
    });

    test('no inventa resultados', () {
      expect(matchTopics('ballena', topics), isEmpty);
      expect(matchTopics('', topics), isEmpty);
      expect(matchTopics('de la', topics), isEmpty); // solo palabras vacías
    });

    test('respeta el límite', () {
      final many = [
        for (var i = 0; i < 9; i++) _topic('Amor $i', const ['amor']),
      ];
      expect(matchTopics('amor', many, limit: 3), hasLength(3));
    });
  });
}
