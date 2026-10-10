import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_bible/data/verse_text.dart';

void main() {
  // Corpus mínimo: "Jehová" y "Dios" aparecen con mayúscula a mitad de frase
  // (nombres propios); "y", "es" y "él" aparecen en minúscula.
  final properNouns = properNounsFrom(const [
    'Porque Jehová da la sabiduría, y de su boca viene el conocimiento.',
    'Hijo mío, no te olvides de mi ley, y tu corazón guarde mis mandamientos.',
    'Busca a Jehová, y él es tu Dios.',
  ]);

  String norm(String s) => normalizeVerseText(s, properNouns);

  group('properNounsFrom', () {
    test('detecta palabras con mayúscula a mitad de frase', () {
      expect(properNouns, containsAll(['Jehová', 'Dios']));
    });

    test('ignora palabras comunes', () {
      expect(properNouns, isNot(contains('Y')));
      expect(properNouns, isNot(contains('Es')));
    });
  });

  group('normalizeVerseText', () {
    test('separa líneas poéticas unidas tras coma y pone minúscula', () {
      expect(
        norm(
          'Hijo mío, si recibieres mis palabras,Y mis mandamientos '
          'guardares dentro de ti,  ',
        ),
        'Hijo mío, si recibieres mis palabras, y mis mandamientos '
        'guardares dentro de ti,',
      );
    });

    test('separa tras punto y coma', () {
      expect(
        norm(
          'Él provee de sana sabiduría a los rectos;Es escudo a los que '
          'caminan rectamente.',
        ),
        'Él provee de sana sabiduría a los rectos; es escudo a los que '
        'caminan rectamente.',
      );
    });

    test('separa palabras pegadas sin puntuación', () {
      expect(
        norm('El que quiere amar la vidaY ver días buenos,Y sus labios'),
        'El que quiere amar la vida y ver días buenos, y sus labios',
      );
    });

    test('conserva la mayúscula de los nombres propios', () {
      expect(
        norm('Haz memoria de tu Creador;Jehová es tu fortaleza,Dios eterno.'),
        'Haz memoria de tu Creador; Jehová es tu fortaleza, Dios eterno.',
      );
    });

    test('pasa a minúscula palabras sin evidencia de ser nombre propio', () {
      // Casi siempre son verbos que aparecen una sola vez ('Refrene').
      expect(
        norm('El que quiere amar la vida,Refrene su lengua'),
        'El que quiere amar la vida, refrene su lengua',
      );
    });

    test('tras punto, dos puntos, ? o ! solo añade el espacio', () {
      expect(
        norm('Pues está escrito:Destruiré la sabiduría.Y dijo'),
        'Pues está escrito: Destruiré la sabiduría. Y dijo',
      );
      expect(
        norm('¿cuánto más nosotros?Pero no hemos usado'),
        '¿cuánto más nosotros? Pero no hemos usado',
      );
      expect(
        norm('¡Cómo han caído!¡Jonatán, muerto!'),
        '¡Cómo han caído! ¡Jonatán, muerto!',
      );
    });

    test('pregunta tras coma o punto y coma va en minúscula', () {
      expect(
        norm('pero yo sé que es así;¿Y cómo se justificará el hombre?'),
        'pero yo sé que es así; ¿y cómo se justificará el hombre?',
      );
    });

    test('separa aunque la línea siguiente empiece en minúscula', () {
      expect(
        norm('roca que hace caer,porque tropiezan'),
        'roca que hace caer, porque tropiezan',
      );
    });

    test('no altera un texto ya correcto', () {
      const ok = 'En el principio creó Dios los cielos y la tierra.';
      expect(norm(ok), ok);
      expect(
        norm('Jehová es mi pastor; nada me faltará.'),
        'Jehová es mi pastor; nada me faltará.',
      );
    });

    test('no separa cifras con punto', () {
      expect(norm('fueron 3.000 hombres'), 'fueron 3.000 hombres');
    });
  });
}
