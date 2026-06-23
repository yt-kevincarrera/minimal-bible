import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/books.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'reader_screen.dart';

class ChaptersScreen extends ConsumerWidget {
  final Book book;
  const ChaptersScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final lastChapter = ref.watch(
      readingProgressProvider.select((p) => p.chapterOf(book.id)),
    );
    final synopsis = synopsisFor(book.id);

    return Scaffold(
      appBar: AppBar(title: Text(book.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              if (synopsis != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 38,
                        margin: const EdgeInsets.only(top: 2, right: 12),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          synopsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.inkSoft,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: GridView.builder(
                    itemCount: book.chapterCount,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 72,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                    itemBuilder: (context, i) {
                      final ch = i + 1;
                      final isLast = ch == lastChapter;
                      return Material(
                        color: isLast
                            ? colors.accent.withValues(alpha: 0.12)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReaderScreen(bookId: book.id, chapter: ch),
                            ),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isLast ? colors.accent : colors.divider,
                                width: isLast ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              '$ch',
                              style: TextStyle(
                                fontFamily: 'CrimsonPro',
                                fontSize: 20,
                                fontWeight: isLast
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isLast ? colors.accent : colors.ink,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
