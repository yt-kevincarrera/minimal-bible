import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'reader_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar en la Biblia…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colors.inkSoft,
              fontSize: 16,
            ),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Limpiar',
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).state = '';
                _focus.requestFocus();
                setState(() {});
              },
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (query.trim().length < 2) {
            return _EmptyState(
              icon: Icons.search,
              title: 'Escribe al menos 2 letras',
              subtitle:
                  'Busca por palabras o frases. Tilde opcional: "jesus" encuentra "Jesús".',
            );
          }
          return resultsAsync.when(
            loading: () => Column(
              children: [
                LinearProgressIndicator(
                  minHeight: 2,
                  color: colors.accent,
                  backgroundColor: colors.divider,
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (hits) {
              if (hits.isEmpty) {
                return _EmptyState(
                  icon: Icons.search_off_outlined,
                  title: 'Sin resultados',
                  subtitle: 'Prueba con otras palabras.',
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${hits.length} resultado${hits.length == 1 ? '' : 's'}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.inkSoft,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: hits.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: colors.divider),
                          itemBuilder: (_, i) => _HitTile(hit: hits[i]),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HitTile extends ConsumerWidget {
  final SearchHit hit;
  const _HitTile({required this.hit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final scale = ref.watch(fontScaleProvider);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            bookId: hit.bookId,
            chapter: hit.chapter,
            verseToHighlight: hit.verse,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hit.reference,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.accent,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16 * scale,
                  height: 1.5,
                ),
                children: _parseSnippet(hit.snippet, colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _parseSnippet(String snippet, AppColors colors) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'<b>(.*?)</b>');
    int i = 0;
    for (final m in re.allMatches(snippet)) {
      if (m.start > i) spans.add(TextSpan(text: snippet.substring(i, m.start)));
      spans.add(
        TextSpan(
          text: m.group(1),
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.accent),
        ),
      );
      i = m.end;
    }
    if (i < snippet.length) {
      spans.add(TextSpan(text: snippet.substring(i)));
    }
    return spans;
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.inkSoft),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
