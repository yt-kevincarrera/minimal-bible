import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'reader_screen.dart';

class CollectionDetailScreen extends ConsumerWidget {
  final Collection collection;
  const CollectionDetailScreen({super.key, required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final scale = ref.watch(fontScaleProvider);
    final versesAsync = ref.watch(collectionVersesProvider(collection.id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (collection.isFavorites)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.favorite, size: 18, color: colors.accent),
              ),
            Flexible(
              child: Text(collection.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: versesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (verses) {
          if (verses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 40,
                      color: colors.inkSoft,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no hay versículos aquí',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mantén pulsado un versículo mientras lees para '
                      'seleccionarlo y guardarlo.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }
          final groups = groupByBatch(verses);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  _SwipeHint(
                    text: collection.isFavorites
                        ? 'Desliza un grupo a la izquierda para quitarlo de Favoritos'
                        : 'Desliza un grupo a la izquierda para quitarlo',
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: colors.divider),
                      itemBuilder: (_, i) => _GroupTile(
                        collectionId: collection.id,
                        group: groups[i],
                        scale: scale,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  final String text;
  const _SwipeHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Icon(Icons.swipe_left_outlined, size: 16, color: colors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo de versículos guardados juntos, mostrado de forma compacta y
/// expandible para no alargar la lista.
class _GroupTile extends ConsumerStatefulWidget {
  final int collectionId;
  final VerseGroup group;
  final double scale;
  const _GroupTile({
    required this.collectionId,
    required this.group,
    required this.scale,
  });

  @override
  ConsumerState<_GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends ConsumerState<_GroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final group = widget.group;
    final multi = group.verses.length > 1;

    return Slidable(
      key: ValueKey('${widget.collectionId}_${group.verses.first.verseId}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final repo = await ref.read(repositoryProvider.future);
              await repo.removeVersesFromCollection(
                widget.collectionId,
                group.verseIds,
              );
              ref.invalidate(collectionVersesProvider(widget.collectionId));
              ref.invalidate(collectionsProvider);
              ref.invalidate(chapterFavoritesProvider);
            },
            backgroundColor: const Color(0xFFB3261E),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Quitar',
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              bookId: group.verses.first.bookId,
              chapter: group.verses.first.chapter,
              verseToHighlight: group.verses.first.verse,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.reference,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.accent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (multi)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            Text(
                              '${group.verses.length} vers.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.inkSoft,
                              ),
                            ),
                            Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: colors.inkSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (multi && !_expanded)
                Text(
                  group.verses.map((v) => v.text).join(' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16 * widget.scale,
                    height: 1.5,
                  ),
                )
              else
                ...group.verses.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 17 * widget.scale,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: '${v.verse} ',
                            style: TextStyle(
                              color: colors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12 * widget.scale,
                            ),
                          ),
                          TextSpan(text: v.text),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
