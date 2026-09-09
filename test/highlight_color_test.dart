import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_bible/theme.dart';

/// Los resaltados y el acento guardan un solo entero: índice de la paleta
/// predefinida o, si supera [kCustomColorFlag], un color libre empaquetado.
/// Estos tests fijan esa convención (de ella depende lo ya guardado en la
/// base de datos y en los respaldos).
void main() {
  group('codificación de colores libres', () {
    test('los índices predefinidos no se confunden con colores libres', () {
      for (var i = 0; i < highlightSwatches.length; i++) {
        expect(isCustomColor(i), isFalse);
      }
      expect(isCustomColor(-1), isFalse);
    });

    test('ida y vuelta de un color libre', () {
      const color = Color(0xFF3F7FBF);
      final value = encodeCustomColor(color);
      expect(isCustomColor(value), isTrue);
      expect(decodeCustomColor(value), const Color(0xFF3F7FBF));
    });

    test('se ignora la transparencia del color elegido', () {
      final value = encodeCustomColor(const Color(0x803F7FBF));
      expect(decodeCustomColor(value), const Color(0xFF3F7FBF));
    });

    test('hex legible en mayúsculas y con ceros', () {
      expect(hexOf(const Color(0xFF0A0B0C)), '#0A0B0C');
      expect(hexOf(const Color(0xFF000000)), '#000000');
    });
  });

  group('color mostrado', () {
    test('un índice predefinido usa su pareja claro/oscuro', () {
      expect(highlightColorFor(1, false), highlightSwatches[1].light);
      expect(highlightColorFor(1, true), highlightSwatches[1].dark);
    });

    test('un índice fuera de rango cae en el primer color', () {
      expect(highlightColorFor(99, false), highlightSwatches.first.light);
    });

    test('un color libre se respeta en claro y se apaga en oscuro', () {
      const color = Color(0xFF85B6E0);
      final value = encodeCustomColor(color);
      expect(highlightColorFor(value, false), color);

      final dark = highlightColorFor(value, true);
      expect(dark, isNot(color));
      expect(
        HSLColor.fromColor(dark).lightness,
        lessThan(HSLColor.fromColor(color).lightness),
      );
      // Mismo tono: solo cambia cuánto ilumina detrás del texto.
      expect(
        HSLColor.fromColor(dark).hue,
        closeTo(HSLColor.fromColor(color).hue, 1),
      );
    });

    test('el nombre es el de la muestra o el hex del color libre', () {
      expect(highlightNameFor(0), highlightSwatches.first.name);
      expect(
        highlightNameFor(encodeCustomColor(const Color(0xFF3F7FBF))),
        '#3F7FBF',
      );
    });
  });

  group('acento libre', () {
    test('los índices siguen apuntando a las paletas de siempre', () {
      expect(accentPaletteFor(2).name, accentPalettes[2].name);
      expect(accentColorFor(2, true), accentPalettes[2].dark);
    });

    test('un acento muy claro se oscurece para el tema claro', () {
      final palette = customAccentPalette(const Color(0xFFF6E7B0));
      expect(HSLColor.fromColor(palette.light).lightness, lessThan(0.5));
    });

    test('un acento muy oscuro se aclara para el tema oscuro', () {
      final palette = customAccentPalette(const Color(0xFF120A22));
      expect(HSLColor.fromColor(palette.dark).lightness, greaterThan(0.55));
    });
  });
}
