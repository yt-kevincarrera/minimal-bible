import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'collection_detail_screen.dart';
import 'color_verses_screen.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final collectionsAsync = ref.watch(collectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva biblioteca',
            onPressed: () => _createPlaylist(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: collectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (collections) {
          final hasPlaylist = collections.any((c) => !c.isFavorites);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  if (hasPlaylist)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swipe_left_outlined,
                            size: 16,
                            color: colors.inkSoft,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Desliza una biblioteca a la izquierda para '
                              'renombrarla o borrarla',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final c in collections) ...[
                    _CollectionTile(collection: c),
                    Divider(height: 1, color: colors.divider),
                  ],
                  const _ColorsSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollectionTile extends ConsumerWidget {
  final Collection collection;
  const _CollectionTile({required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final tile = InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CollectionDetailScreen(collection: collection),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              collection.isFavorites
                  ? Icons.favorite
                  : Icons.playlist_play_rounded,
              size: 22,
              color: collection.isFavorites ? colors.accent : colors.inkSoft,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(collection.name, style: theme.textTheme.titleMedium),
            ),
            Text(
              '${collection.verseCount}',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: colors.inkSoft),
          ],
        ),
      ),
    );

    if (collection.isFavorites) return tile;

    return Slidable(
      key: ValueKey(collection.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _rename(context, ref, collection),
            backgroundColor: colors.inkSoft,
            foregroundColor: colors.bg,
            icon: Icons.edit_outlined,
            label: 'Renombrar',
          ),
          SlidableAction(
            onPressed: (_) => _delete(context, ref, collection),
            backgroundColor: const Color(0xFFB3261E),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Borrar',
          ),
        ],
      ),
      child: tile,
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Collection c,
  ) async {
    final name = await _promptName(
      context,
      initial: c.name,
      title: 'Renombrar',
    );
    if (name == null || name.isEmpty) return;
    final repo = await ref.read(repositoryProvider.future);
    await repo.renameCollection(c.id, name);
    ref.invalidate(collectionsProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Collection c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar biblioteca'),
        content: Text(
          '"${c.name}" se va con to\' lo que metiste dentro, y no hay '
          'vuelta atrás.\n\n'
          'Los versículos siguen en la Biblia, tranquilo… esto solo borra '
          'la colección. ¿La soltamos? 👋',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mejor no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dale'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = await ref.read(repositoryProvider.future);
    await repo.deleteCollection(c.id);
    ref.invalidate(collectionsProvider);
  }
}

class _ColorsSection extends ConsumerWidget {
  const _ColorsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final countsAsync = ref.watch(highlightCountsProvider);

    return countsAsync.maybeWhen(
      data: (counts) {
        if (counts.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COLORES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.inkSoft,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < highlightSwatches.length; i++)
                    if ((counts[i] ?? 0) > 0)
                      _ColorChip(
                        index: i,
                        count: counts[i]!,
                        color: highlightColorFor(i, isDark),
                      ),
                ],
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final int index;
  final int count;
  final Color color;
  const _ColorChip({
    required this.index,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ColorVersesScreen(colorIndex: index)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '${highlightSwatches[index].name} · $count',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
  final name = await _promptName(context, title: 'Nueva biblioteca');
  if (name == null || name.isEmpty) return;
  final repo = await ref.read(repositoryProvider.future);
  await repo.createCollection(name);
  ref.invalidate(collectionsProvider);
}

Future<String?> _promptName(
  BuildContext context, {
  String initial = '',
  required String title,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nombre'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
