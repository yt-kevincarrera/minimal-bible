import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'reader_screen.dart';

/// Muestra los versículos de un tema/pasaje del índice curado. Cada versículo
/// abre el lector en su ubicación.
class TopicScreen extends ConsumerStatefulWidget {
  final Topic topic;
  const TopicScreen({super.key, required this.topic});

  @override
  ConsumerState<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends ConsumerState<TopicScreen> {
  late Future<List<SavedVerse>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SavedVerse>> _load() async {
    final repo = await ref.read(repositoryProvider.future);
    return repo.versesByRefs(widget.topic.refs);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title)),
      body: FutureBuilder<List<SavedVerse>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final verses = snap.data ?? const <SavedVerse>[];
          if (verses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No se pudieron cargar los versículos de este tema.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.inkSoft,
                  ),
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: verses.length + 1,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: colors.divider),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text(
                        widget.topic.category.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.inkSoft,
                          letterSpacing: 1.4,
                        ),
                      ),
                    );
                  }
                  final v = verses[i - 1];
                  return _VerseTile(verse: v);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VerseTile extends ConsumerWidget {
  final SavedVerse verse;
  const _VerseTile({required this.verse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final scale = ref.watch(fontScaleProvider);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            bookId: verse.bookId,
            chapter: verse.chapter,
            verseToHighlight: verse.verse,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verse.reference,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.accent,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              verse.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16 * scale,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
