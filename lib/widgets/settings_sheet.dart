import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../state/providers.dart';
import '../theme.dart';

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
    final mode = ref.watch(themeModeProvider);
    final accentIndex = ref.watch(accentProvider);

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
                    _AccentDot(
                      palette: accentPalettes[i],
                      selected: i == accentIndex,
                      onTap: () => ref.read(accentProvider.notifier).set(i),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                accentPalettes[accentIndex.clamp(0, accentPalettes.length - 1)]
                    .name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkSoft,
                ),
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

class _AccentDot extends StatelessWidget {
  final AccentPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _AccentDot({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? palette.dark : palette.light;
    final colors = context.appColors;
    return Tooltip(
      message: palette.name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.ink : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? Icon(Icons.check, size: 18, color: colors.bg)
              : null,
        ),
      ),
    );
  }
}
