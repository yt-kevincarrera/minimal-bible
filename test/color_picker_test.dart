import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_bible/theme.dart';
import 'package:minimal_bible/widgets/color_picker_sheet.dart';

/// Abre el selector dentro de una app con el tema de la aplicación (el
/// selector lee AppColors del tema). La lista recibe lo que devuelva el
/// selector al cerrarse: un color, o null si se canceló.
Future<List<Color?>> _open(WidgetTester tester, {required Color initial}) async {
  final results = <Color?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(accentPalettes.first),
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              results.add(
                await showFreeColorPicker(
                  context,
                  title: 'COLOR',
                  initial: initial,
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('escribir un hex y aplicarlo devuelve ese color', (tester) async {
    final results = await _open(tester, initial: const Color(0xFF85B6E0));
    expect(find.text('Usar este color'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '#123456');
    await tester.pump();
    await tester.tap(find.text('Usar este color'));
    await tester.pumpAndSettle();

    expect(results.single, isNotNull);
    expect(hexOf(results.single!), '#123456');
  });

  testWidgets('cancelar no devuelve color', (tester) async {
    final results = await _open(tester, initial: const Color(0xFF85B6E0));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(results.single, isNull);
    expect(find.text('Usar este color'), findsNothing);
  });

  testWidgets('el hex sigue al plano de saturación/brillo', (tester) async {
    await _open(tester, initial: const Color(0xFF85B6E0));
    final field = find.byType(TextField);
    final before = tester.widget<TextField>(field).controller!.text;

    // Esquina superior derecha del plano: saturación y brillo al máximo.
    final plane = tester.getRect(find.byType(ClipRRect).first);
    await tester.tapAt(Offset(plane.right - 2, plane.top + 2));
    await tester.pump();

    final after = tester.widget<TextField>(field).controller!.text;
    expect(after, isNot(before));
    expect(after, startsWith('#'));
  });
}
