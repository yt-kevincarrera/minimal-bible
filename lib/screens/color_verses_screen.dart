import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'reader_screen.dart';

class ColorVersesScreen extends ConsumerWidget {
  final int colorIndex;
  const ColorVersesScreen({super.key, required this.colorIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scale = ref.watch(fontScaleProvider);
    final versesAsync = ref.watch(versesByColorProvider(colorIndex));
    final swatch =
        highlightSwatches[colorIndex.clamp(0, highlightSwatches.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: highlightColorFor(colorIndex, isDark),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(swatch.name),
          ],
        ),
      ),
      body: versesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (verses) {
          if (verses.isEmpty) {
            return Center(
              child: Text(
                'Sin versículos de este color',
                style: theme.textTheme.bodySmall,
              ),
            );
          }
          final groups = groupByBatch(verses);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
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
                            'Desliza un grupo a la izquierda para quitar el color',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: colors.divider),
                      itemBuilder: (_, i) => _GroupTile(
                        colorIndex: colorIndex,
                        group: groups[i],
                        scale: scale,
                        swatchColor: highlightColorFor(colorIndex, isDark),
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

class _GroupTile extends ConsumerStatefulWidget {
  final int colorIndex;
  final VerseGroup group;
  final double scale;
  final Color swatchColor;
  const _GroupTile({
    required this.colorIndex,
    required this.group,
    required this.scale,
    required this.swatchColor,
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
      key: ValueKey('color_${widget.colorIndex}_${group.verses.first.verseId}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final repo = await ref.read(repositoryProvider.future);
              await repo.removeHighlights(group.verseIds);
              ref.invalidate(versesByColorProvider(widget.colorIndex));
              ref.invalidate(highlightCountsProvider);
              ref.invalidate(chapterHighlightsProvider);
            },
            backgroundColor: const Color(0xFFB3261E),
            foregroundColor: Colors.white,
            icon: Icons.format_color_reset_outlined,
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
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.swatchColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
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
