import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/books.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/settings_sheet.dart';
import 'chapters_screen.dart';
import 'collections_screen.dart';
import 'info_screen.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final theme = Theme.of(context);
    final colors = context.appColors;

    return booksAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (books) {
        final ot = books.where((b) => b.testament == testamentOld).toList();
        final nt = books.where((b) => b.testament == testamentNew).toList();
        return DefaultTabController(
          length: 2,
          initialIndex: ref.read(tabIndexProvider).clamp(0, 1),
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'La Biblia',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    'Reina-Valera 1960',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.inkSoft,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Buscar',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmarks_outlined),
                  tooltip: 'Guardados',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CollectionsScreen(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.insights_outlined),
                  tooltip: 'Tu lectura',
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Ajustes y color',
                  onPressed: () => showSettingsSheet(context),
                ),
                const SizedBox(width: 4),
              ],
              bottom: TabBar(
                labelColor: colors.accent,
                unselectedLabelColor: colors.inkSoft,
                indicatorColor: colors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                labelStyle: theme.textTheme.labelLarge,
                unselectedLabelStyle: theme.textTheme.labelLarge,
                onTap: (i) => ref.read(tabIndexProvider.notifier).set(i),
                tabs: const [
                  Tab(text: 'Antiguo Testamento'),
                  Tab(text: 'Nuevo Testamento'),
                ],
              ),
            ),
            body: Column(
              children: [
                const _ContinueReadingCard(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _BookList(books: ot),
                      _BookList(books: nt),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookList extends StatelessWidget {
  final List<Book> books;
  const _BookList({required this.books});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 24, top: 4),
          itemCount: books.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: colors.divider),
          itemBuilder: (_, i) => _BookTile(book: books[i]),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Book book;
  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    return InkWell(
      onTap: () {
        if (book.chapterCount == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReaderScreen(bookId: book.id, chapter: 1),
            ),
          );
        } else {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => ChaptersScreen(book: book)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                book.id.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Text(book.name, style: theme.textTheme.titleMedium),
            ),
            Text('${book.chapterCount} cap.', style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: colors.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends ConsumerWidget {
  const _ContinueReadingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(readingProgressProvider);
    final bookId = progress.lastBookId;
    final chapter = progress.lastChapter;
    if (bookId == null || chapter == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = context.appColors;

    final bookAsync = ref.watch(bookProvider(bookId));
    return bookAsync.maybeWhen(
      data: (book) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReaderScreen(bookId: bookId, chapter: chapter),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 20,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CONTINUAR LEYENDO',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.inkSoft,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${book.name} $chapter',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: colors.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
