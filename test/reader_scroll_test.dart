import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_bible/screens/reader_screen.dart';

/// Posiciones de versículos como las mide el lector: en píxeles de scroll y en
/// orden creciente (los que caen en la misma línea comparten posición).
void main() {
  group('activeVerseIndex', () {
    test('al principio del capítulo, el primer versículo', () {
      expect(activeVerseIndex(const [0, 100, 200], 0), 0);
    });

    test('marca el último versículo que ya pasó por arriba', () {
      const offsets = [0.0, 100.0, 200.0, 300.0];
      expect(activeVerseIndex(offsets, 90), 1); // 100 - 16 de margen
      expect(activeVerseIndex(offsets, 84), 1); // justo en el margen
      expect(activeVerseIndex(offsets, 83), 0); // aún no llega
      expect(activeVerseIndex(offsets, 250), 2);
      expect(activeVerseIndex(offsets, 400), 3);
    });

    test('con posiciones repetidas (misma línea) elige la última', () {
      // Tres versículos cortos en la misma línea, luego uno más abajo.
      const offsets = [0.0, 40.0, 40.0, 40.0, 90.0];
      expect(activeVerseIndex(offsets, 30), 3);
      expect(activeVerseIndex(offsets, 80), 4);
    });

    test('un solo versículo', () {
      expect(activeVerseIndex(const [0], 0), 0);
      expect(activeVerseIndex(const [0], 500), 0);
    });

    test('nunca sale del rango', () {
      const offsets = [0.0, 50.0, 120.0];
      for (var px = -50.0; px < 400; px += 7) {
        final i = activeVerseIndex(offsets, px);
        expect(i, greaterThanOrEqualTo(0));
        expect(i, lessThan(offsets.length));
      }
    });

    test('coincide con el recorrido lineal que sustituye', () {
      const offsets = [0.0, 30.0, 30.0, 95.0, 140.0, 140.0, 260.0, 300.0];
      int linear(double pixels) {
        var active = 0;
        for (var i = 0; i < offsets.length; i++) {
          if (offsets[i] <= pixels + 16) {
            active = i;
          } else {
            break;
          }
        }
        return active;
      }

      for (var px = -20.0; px < 350; px += 1) {
        expect(activeVerseIndex(offsets, px), linear(px), reason: 'px=$px');
      }
    });
  });
}
