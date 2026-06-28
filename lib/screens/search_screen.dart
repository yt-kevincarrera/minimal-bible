import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/books.dart';
import '../data/models.dart';
import '../data/reference.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'chapters_screen.dart';
import 'reader_screen.dart';
import 'topic_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool _showFilters = false;

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

  void _runRecent(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    ref.read(searchQueryProvider.notifier).state = q;
    ref.read(recentSearchesProvider.notifier).add(q); // lo sube arriba
    setState(() {});
  }

  /// Pantalla cuando aún no se busca: muestra búsquedas recientes si las hay,
  /// o una ayuda breve.
  Widget _buildIdleState() {
    final recents = ref.watch(recentSearchesProvider);
    if (recents.isEmpty) {
      return _EmptyState(
        icon: Icons.search,
        title: 'Escribe al menos 2 letras',
        subtitle:
            'Busca por palabras o frases (tilde opcional: "jesus" encuentra '
            '"Jesús"). También una cita como "Jn 3:16" o un tema como '
            '"ansiedad" o "parábola del sembrador".',
      );
    }
    final colors = context.appColors;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Row(
          children: [
            Text(
              'BÚSQUEDAS RECIENTES',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.inkSoft,
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  ref.read(recentSearchesProvider.notifier).clear(),
              child: const Text('Borrar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in recents)
              ActionChip(
                label: Text(q),
                avatar: Icon(Icons.history, size: 18, color: colors.inkSoft),
                side: BorderSide(color: colors.divider),
                onPressed: () => _runRecent(q),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final filtersActive =
        ref.watch(searchScopeProvider) != SearchScope.all ||
        ref.watch(searchPhraseProvider);
    final books = ref.watch(booksProvider).valueOrNull ?? const <Book>[];
    final goto = books.isEmpty ? null : parseReference(query, books);
    final topics = ref.watch(topicsProvider).valueOrNull ?? const <Topic>[];
    final topicHits = query.trim().length >= 2
        ? matchTopics(query, topics)
        : const <Topic>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          onSubmitted: (v) =>
              ref.read(recentSearchesProvider.notifier).add(v),
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
          IconButton(
            icon: Icon(
              _showFilters ? Icons.tune : Icons.tune_outlined,
              color: filtersActive ? colors.accent : null,
            ),
            tooltip: 'Filtros de búsqueda',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Abreviaturas y cómo buscar una cita',
            onPressed: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => const _AbbreviationsSheet(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros ocultos por defecto (no invasivos): se abren con el icono.
          if (_showFilters) ...[
            const _SearchFilters(),
            Divider(height: 1, color: colors.divider),
          ],
          // "Ir a cita" cuando la consulta es una referencia (Jn 3:16).
          if (goto != null) ...[
            _GotoTile(target: goto),
            Divider(height: 1, color: colors.divider),
          ],
          // Temas/pasajes que coinciden (extra sobre la búsqueda normal).
          if (topicHits.isNotEmpty) ...[
            _TopicHits(topics: topicHits),
            Divider(height: 1, color: colors.divider),
          ],
          Expanded(
            child: Builder(
              builder: (context) {
                if (query.trim().length < 2) {
                  return _buildIdleState();
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
                        subtitle: 'Prueba con otras palabras o cambia el filtro.',
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
          ),
        ],
      ),
    );
  }
}

/// Fila de filtros de la búsqueda avanzada: alcance (toda la Biblia / Antiguo
/// / Nuevo) y modo frase exacta. Visible siempre, para que se descubra.
class _SearchFilters extends ConsumerWidget {
  const _SearchFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final scope = ref.watch(searchScopeProvider);
    final phrase = ref.watch(searchPhraseProvider);

    Widget scopeChip(SearchScope s, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: scope == s,
        showCheckmark: false,
        selectedColor: colors.accent.withValues(alpha: 0.18),
        side: BorderSide(color: scope == s ? colors.accent : colors.divider),
        onSelected: (_) =>
            ref.read(searchScopeProvider.notifier).state = s,
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          scopeChip(SearchScope.all, 'Toda la Biblia'),
          scopeChip(SearchScope.oldT, 'Antiguo'),
          scopeChip(SearchScope.newT, 'Nuevo'),
          Container(
            width: 1,
            height: 26,
            color: colors.divider,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 4),
          FilterChip(
            label: const Text('Frase exacta'),
            selected: phrase,
            showCheckmark: true,
            selectedColor: colors.accent.withValues(alpha: 0.18),
            checkmarkColor: colors.accent,
            side: BorderSide(color: phrase ? colors.accent : colors.divider),
            onSelected: (v) =>
                ref.read(searchPhraseProvider.notifier).state = v,
          ),
        ],
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
      onTap: () {
        ref.read(recentSearchesProvider.notifier).add(ref.read(searchQueryProvider));
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              bookId: hit.bookId,
              chapter: hit.chapter,
              verseToHighlight: hit.verse,
            ),
          ),
        );
      },
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

/// Tarjeta "Ir a {cita}" que aparece arriba cuando la consulta es una
/// referencia. Con capítulo salta al lector; con solo el libro abre la
/// pantalla de selección de capítulos.
class _GotoTile extends StatelessWidget {
  final Reference target;
  const _GotoTile({required this.target});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final book = target.book;
    final chapter = target.chapter;
    final verse = target.verse;
    final label = chapter == null
        ? book.name
        : (verse == null
              ? '${book.name} $chapter'
              : '${book.name} $chapter:$verse');
    return Material(
      color: colors.accent.withValues(alpha: 0.10),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => chapter == null
                ? ChaptersScreen(book: book)
                : ReaderScreen(
                    bookId: book.id,
                    chapter: chapter,
                    verseToHighlight: verse,
                  ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.my_location, size: 20, color: colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Ir a '),
                      TextSpan(
                        text: label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.ink,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Icon(Icons.arrow_forward, size: 18, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista compacta de temas/pasajes que coinciden con la consulta.
class _TopicHits extends StatelessWidget {
  final List<Topic> topics;
  const _TopicHits({required this.topics});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            'TEMAS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.inkSoft,
              letterSpacing: 1.4,
            ),
          ),
        ),
        for (final t in topics)
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TopicScreen(topic: t)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_outlined,
                      size: 20, color: colors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${t.category} · ${t.refs.length} versículo'
                          '${t.refs.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: colors.inkSoft),
                ],
              ),
            ),
          ),
      ],
    );
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

/// Hoja con la ayuda de abreviaturas y el formato de cita. La gente no tiene
/// por qué saberse las abreviaturas, así que aquí las ve todas.
class _AbbreviationsSheet extends StatelessWidget {
  const _AbbreviationsSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final old = canonicalBooks.where((b) => b.testament == testamentOld);
    final neu = canonicalBooks.where((b) => b.testament == testamentNew);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('Cómo ir a una cita', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _formatRow(theme, colors, 'Jn 3:16', 'capítulo y versículo'),
            _formatRow(theme, colors, 'Juan 3', 'un capítulo entero'),
            _formatRow(theme, colors, '1 Co 13', 'libros con número'),
            _formatRow(theme, colors, 'Jn', 'solo el libro → elegir capítulo'),
            const SizedBox(height: 8),
            Text(
              'Puedes escribir el nombre completo o la abreviatura. No '
              'importan las mayúsculas ni las tildes.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
            ),
            const SizedBox(height: 20),
            _abbrHeader(theme, colors, 'ANTIGUO TESTAMENTO'),
            for (final b in old) _abbrRow(theme, colors, b),
            const SizedBox(height: 16),
            _abbrHeader(theme, colors, 'NUEVO TESTAMENTO'),
            for (final b in neu) _abbrRow(theme, colors, b),
          ],
        ),
      ),
    );
  }

  Widget _formatRow(
    ThemeData theme,
    AppColors colors,
    String example,
    String desc,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            example,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            desc,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.ink),
          ),
        ),
      ],
    ),
  );

  Widget _abbrHeader(ThemeData theme, AppColors colors, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: colors.inkSoft,
        letterSpacing: 1.6,
      ),
    ),
  );

  Widget _abbrRow(ThemeData theme, AppColors colors, BookDef b) {
    final aliases = bookGotoAliases[b.id] ?? const <String>[];
    final alias = aliases.isNotEmpty ? aliases.first : b.abbr;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              alias,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(b.name, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
