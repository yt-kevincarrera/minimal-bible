import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme.dart';

/// Muestra la hoja para añadir [verseIds] a una playlist.
/// Devuelve el nombre de la playlist usada, o null si se canceló.
Future<String?> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<int> verseIds,
) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AddToPlaylistSheet(verseIds: verseIds),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  final List<int> verseIds;
  const _AddToPlaylistSheet({required this.verseIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final collectionsAsync = ref.watch(collectionsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'AÑADIR A',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.inkSoft,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.add, color: colors.accent),
              title: Text(
                'Nueva biblioteca',
                style: theme.textTheme.titleMedium,
              ),
              onTap: () => _createAndAdd(context, ref),
            ),
            Divider(height: 1, color: colors.divider),
            Flexible(
              child: collectionsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e'),
                ),
                data: (collections) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: collections.length,
                  itemBuilder: (_, i) {
                    final c = collections[i];
                    return ListTile(
                      leading: Icon(
                        c.isFavorites
                            ? Icons.favorite
                            : Icons.playlist_play_rounded,
                        color: c.isFavorites ? colors.accent : colors.inkSoft,
                      ),
                      title: Text(c.name, style: theme.textTheme.titleMedium),
                      trailing: Text(
                        '${c.verseCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.inkSoft,
                        ),
                      ),
                      onTap: () => _addTo(context, ref, c.id, c.name),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTo(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,
  ) async {
    final repo = await ref.read(repositoryProvider.future);
    await repo.addVersesToCollection(id, verseIds);
    ref.invalidate(collectionsProvider);
    ref.invalidate(collectionVersesProvider(id));
    if (context.mounted) Navigator.pop(context, name);
  }

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva biblioteca'),
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
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final repo = await ref.read(repositoryProvider.future);
    final id = await repo.createCollection(name);
    await repo.addVersesToCollection(id, verseIds);
    ref.invalidate(collectionsProvider);
    ref.invalidate(collectionVersesProvider(id));
    if (context.mounted) Navigator.pop(context, name);
  }
}
