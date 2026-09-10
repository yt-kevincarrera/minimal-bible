import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../state/providers.dart';
import '../theme.dart';
import 'color_picker_sheet.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final mode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentProvider);
    final customHighlights = ref.watch(customHighlightsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(context, 'TEMA'),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Claro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Oscuro'),
                  ),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).setMode(s.first),
              ),
              const SizedBox(height: 24),
              _label(context, 'COLOR DE ACENTO'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < accentPalettes.length; i++)
                    ColorDot(
                      color: accentColorFor(i, isDark),
                      tooltip: accentPalettes[i].name,
                      selected: i == accent,
                      size: 40,
                      onTap: () => ref.read(accentProvider.notifier).set(i),
                    ),
                  // Muestra arcoíris: abre el selector libre.
                  ColorDot(
                    color: isCustomColor(accent)
                        ? accentColorFor(accent, isDark)
                        : null,
                    tooltip: 'Elegir otro color',
                    selected: isCustomColor(accent),
                    icon: Icons.add,
                    size: 40,
                    onTap: () => _pickAccent(context, ref, accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isCustomColor(accent)
                    ? 'Personalizado · ${hexOf(decodeCustomColor(accent))}'
                    : accentPaletteFor(accent).name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkSoft,
                ),
              ),
              const SizedBox(height: 24),
              _label(context, 'COLORES PARA RESALTAR'),
              const SizedBox(height: 6),
              Text(
                'Los seis de siempre están fijos. Los que añadas aquí '
                'aparecen también al resaltar versículos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkSoft,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < highlightSwatches.length; i++)
                    ColorDot(
                      color: highlightColorFor(i, isDark),
                      tooltip: highlightSwatches[i].name,
                      size: 40,
                    ),
                  for (final value in customHighlights)
                    ColorDot(
                      color: highlightColorFor(value, isDark),
                      tooltip:
                          '${highlightNameFor(value)} · toca para '
                          'editarlo, mantén pulsado para quitarlo',
                      size: 40,
                      onTap: () => _editHighlight(context, ref, value),
                      onLongPress: () => _removeHighlight(context, ref, value),
                    ),
                  ColorDot(
                    tooltip: 'Añadir un color libre',
                    icon: Icons.add,
                    size: 40,
                    onTap: () => _addHighlight(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _label(context, 'DATOS'),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.ios_share, color: colors.ink),
                title: const Text('Exportar respaldo'),
                subtitle: Text(
                  'Bibliotecas, favoritos, colores y ajustes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkSoft,
                  ),
                ),
                onTap: () => _export(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.download_outlined, color: colors.ink),
                title: const Text('Importar respaldo'),
                subtitle: Text(
                  'Pega un respaldo para restaurar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkSoft,
                  ),
                ),
                onTap: () => _import(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Color(0xFFB3261E),
                ),
                title: const Text('Borrar todos los datos'),
                subtitle: Text(
                  'Bibliotecas, favoritos, colores y estadísticas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkSoft,
                  ),
                ),
                onTap: () => _wipe(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAccent(
    BuildContext context,
    WidgetRef ref,
    int accent,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = await showFreeColorPicker(
      context,
      title: 'COLOR DE ACENTO',
      initial: accentColorFor(accent, isDark),
      hint:
          'El acento se aclara u oscurece un poco para que se lea bien '
          'en el tema claro y en el oscuro.',
      preview: (ctx, color) => _AccentPreview(color: color),
    );
    if (color == null) return;
    await ref.read(accentProvider.notifier).setCustom(color);
  }

  Future<void> _addHighlight(BuildContext context, WidgetRef ref) async {
    final color = await showFreeColorPicker(
      context,
      title: 'NUEVO COLOR DE RESALTADO',
      initial: highlightSwatches.first.light,
      preview: (ctx, color) => HighlightPreview(color: color),
    );
    if (color == null) return;
    await ref.read(customHighlightsProvider.notifier).add(color);
  }

  Future<void> _editHighlight(
    BuildContext context,
    WidgetRef ref,
    int value,
  ) async {
    final color = await showFreeColorPicker(
      context,
      title: 'EDITAR COLOR',
      initial: decodeCustomColor(value),
      hint: 'Los versículos que ya tienen este color cambian con él.',
      preview: (ctx, color) => HighlightPreview(color: color),
    );
    if (color == null) return;
    final newValue = await ref
        .read(customHighlightsProvider.notifier)
        .replace(value, color);
    final repo = await ref.read(repositoryProvider.future);
    await repo.recolorHighlights(value, newValue);
    ref.invalidate(highlightCountsProvider);
    ref.invalidate(versesByColorProvider);
    ref.invalidate(chapterHighlightsProvider);
  }

  Future<void> _removeHighlight(
    BuildContext context,
    WidgetRef ref,
    int value,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar ${highlightNameFor(value)}?'),
        content: const Text(
          'Sale de tu paleta, pero los versículos que ya marcaste con él '
          'conservan su color.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mejor no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(customHighlightsProvider.notifier).remove(value);
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Borrarlo to'? 😬"),
        content: const Text(
          "Bibliotecas, favoritos, colores y estadísticas se van pa' "
          'siempre. Aquí no hay deshacer ni Ctrl+Z que te salve.\n\n'
          'Pero tranquilo, empezar de cero también tiene lo suyo… ¿hiciste '
          'un respaldo primero? 👀 (El texto bíblico se queda, no te '
          'preocupes.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mejor no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dale, bórralo'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = await ref.read(repositoryProvider.future);
    await repo.wipeUserData();
    await ref.read(readingProgressProvider.notifier).reset();
    await ref.read(customHighlightsProvider.notifier).clear();
    ref.invalidate(collectionsProvider);
    ref.invalidate(collectionVersesProvider);
    ref.invalidate(highlightCountsProvider);
    ref.invalidate(versesByColorProvider);
    ref.invalidate(chapterHighlightsProvider);
    ref.invalidate(chapterFavoritesProvider);
    ref.invalidate(savedVerseCountProvider);
    ref.invalidate(readingSecondsProvider);
    messenger.showSnackBar(
      const SnackBar(content: Text('Todos los datos fueron borrados')),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final svc = await ref.read(backupServiceProvider.future);
    final data = await svc.export();
    await Clipboard.setData(ClipboardData(text: data));
    try {
      await Share.share(data, subject: 'Respaldo · La Biblia');
    } catch (_) {
      // En algunas plataformas (web) compartir puede no estar disponible;
      // el respaldo ya quedó copiado al portapapeles.
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Respaldo copiado al portapapeles')),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar respaldo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 6,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'Pega aquí el contenido del respaldo…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (raw == null || raw.isEmpty) return;

    try {
      final svc = await ref.read(backupServiceProvider.future);
      final summary = await svc.import(raw);
      // Refresca todo lo afectado.
      ref.invalidate(collectionsProvider);
      ref.invalidate(collectionVersesProvider);
      ref.invalidate(highlightCountsProvider);
      ref.invalidate(versesByColorProvider);
      ref.invalidate(chapterHighlightsProvider);
      ref.invalidate(chapterFavoritesProvider);
      ref.invalidate(savedVerseCountProvider);
      ref.invalidate(readingSecondsProvider);
      await ref.read(themeModeProvider.notifier).load();
      await ref.read(accentProvider.notifier).load();
      await ref.read(customHighlightsProvider.notifier).load();
      await ref.read(fontScaleProvider.notifier).load();
      await ref.read(keepAwakeProvider.notifier).load();
      await ref.read(readingProgressProvider.notifier).load();
      await ref.read(tabIndexProvider.notifier).load();
      messenger.showSnackBar(SnackBar(content: Text(summary)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo importar: $e')),
      );
    }
  }

  Widget _label(BuildContext context, String text) {
    final colors = context.appColors;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colors.inkSoft,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// Vista previa del acento en el sheet del selector: así se ve cómo queda
/// sobre el papel/carbón del tema actual antes de aplicarlo.
class _AccentPreview extends StatelessWidget {
  final Color color;
  const _AccentPreview({required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = customAccentPalette(color);
    final shown = isDark ? palette.dark : palette.light;
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Text(
            '16 ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: shown,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              'Porque de tal manera amó Dios al mundo…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.bookmark, size: 18, color: shown),
        ],
      ),
    );
  }
}
