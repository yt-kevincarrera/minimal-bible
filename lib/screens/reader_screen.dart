import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/add_to_playlist_sheet.dart';
import 'chapters_screen.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final int bookId;
  final int chapter;
  final int? verseToHighlight;

  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.chapter,
    this.verseToHighlight,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _VerseGestures {
  final LongPressGestureRecognizer longPress;
  final TapGestureRecognizer tap;
  _VerseGestures({required this.longPress, required this.tap});
  void dispose() {
    longPress.dispose();
    tap.dispose();
  }
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {}; // verse number -> key
  final Map<int, _VerseGestures> _gestures = {}; // verse id -> recognizers
  final Set<int> _selectedIds = {};
  bool _selectionMode = false;
  int? _activeHighlight;
  Timer? _highlightTimer;
  bool _resumeInit = false;
  double? _resumeOffset;
  bool _showResume = false;
  ScrollStore? _scrollStore;
  Timer? _saveTimer;

  // Navegador lateral de versículos.
  final GlobalKey _viewportKey = GlobalKey();
  List<int> _verseNumbers = const [];
  int? _previewVerse; // versículo bajo el dedo en la tira
  int? _activeVerse; // versículo actual según el scroll
  int _lastActiveCalc = 0;
  SharedPreferences? _prefs;
  final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _activeHighlight = widget.verseToHighlight;
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollStore = ref.read(scrollStoreProvider.notifier);
      ref.read(sharedPrefsProvider.future).then((p) => _prefs = p);
      if (ref.read(keepAwakeProvider)) WakelockPlus.enable();
      final total = ref
          .read(booksProvider)
          .valueOrNull
          ?.where((b) => b.id == widget.bookId)
          .firstOrNull
          ?.chapterCount;
      ref
          .read(readingProgressProvider.notifier)
          .visit(widget.bookId, widget.chapter, totalChapters: total);
      if (_activeHighlight != null) {
        _scrollToVerse(_activeHighlight!);
        _highlightTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _activeHighlight = null);
        });
      }
    });
  }

  void _onScroll() {
    // Oculta el botón "Continuar" cuando ya estás cerca de esa posición.
    if (_showResume &&
        _resumeOffset != null &&
        (_scroll.offset - _resumeOffset!).abs() < 80) {
      setState(() => _showResume = false);
    }
    // Guarda la posición de forma continua (con pequeño retardo) para que
    // el botón "Continuar" sea fiable aunque la app se cierre de golpe.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_scrollStore != null && _scroll.hasClients) {
        _scrollStore!.save(widget.bookId, widget.chapter, _scroll.offset);
      }
    });
    _recomputeActiveVerse();
  }

  void _recomputeActiveVerse() {
    if (_previewVerse != null || _verseNumbers.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastActiveCalc < 90) return; // throttle
    _lastActiveCalc = now;
    final vp = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (vp == null) return;
    final top = vp.localToGlobal(Offset.zero).dy;
    int? active;
    for (final v in _verseNumbers) {
      final ctx = _verseKeys[v]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= top + 16) {
        active = v;
      } else {
        break;
      }
    }
    active ??= _verseNumbers.first;
    if (active != _activeVerse && mounted) {
      setState(() => _activeVerse = active);
    }
  }

  void _jumpToVerse(int verse) {
    final ctx = _verseKeys[verse]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.12,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToVerse(int verse) {
    final ctx = _verseKeys[verse]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      alignment: 0.15,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _highlightTimer?.cancel();
    _saveTimer?.cancel();
    _scroll.removeListener(_onScroll);
    // Acumula el tiempo de lectura de este capítulo (con tope para no contar
    // sesiones olvidadas abiertas).
    final prefs = _prefs;
    if (prefs != null) {
      final secs = DateTime.now()
          .difference(_openedAt)
          .inSeconds
          .clamp(0, 3600);
      if (secs > 0) {
        prefs.setInt(
          'reading_seconds',
          (prefs.getInt('reading_seconds') ?? 0) + secs,
        );
      }
    }
    if (_scrollStore != null && _scroll.hasClients) {
      _scrollStore!.save(widget.bookId, widget.chapter, _scroll.offset);
    }
    for (final g in _gestures.values) {
      g.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  (int, int)? _adjacent(List<Book> books, int dir) {
    final idx = books.indexWhere((b) => b.id == widget.bookId);
    if (idx < 0) return null;
    final cur = books[idx];
    if (dir > 0) {
      if (widget.chapter < cur.chapterCount) {
        return (widget.bookId, widget.chapter + 1);
      }
      if (idx == books.length - 1) return null;
      return (books[idx + 1].id, 1);
    } else {
      if (widget.chapter > 1) return (widget.bookId, widget.chapter - 1);
      if (idx <= 0) return null;
      final prev = books[idx - 1];
      return (prev.id, prev.chapterCount);
    }
  }

  void _swipeTo(List<Book> books, int dir) {
    final target = _adjacent(books, dir);
    if (target == null) return;
    Navigator.of(context).pushReplacement(
      chapterRoute(
        ReaderScreen(bookId: target.$1, chapter: target.$2),
        forward: dir > 0,
      ),
    );
  }

  void _ensureGestures(List<Verse> verses) {
    for (final v in verses) {
      _gestures.putIfAbsent(
        v.id,
        () => _VerseGestures(
          longPress: LongPressGestureRecognizer(
            duration: const Duration(milliseconds: 280),
          )..onLongPress = () => _enterSelection(v.id),
          tap: TapGestureRecognizer()..onTap = () => _toggleSelect(v.id),
        ),
      );
    }
  }

  void _enterSelection(int verseId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(verseId);
    });
  }

  void _toggleSelect(int verseId) {
    setState(() {
      if (!_selectedIds.remove(verseId)) _selectedIds.add(verseId);
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _toggleFavorites() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final chapterRef = ChapterRef(widget.bookId, widget.chapter);
    final favSet =
        ref.read(chapterFavoritesProvider(chapterRef)).valueOrNull ??
        const <int>{};
    final allFav = ids.every(favSet.contains);
    final repo = await ref.read(repositoryProvider.future);
    final favId = await repo.favoritesId();
    if (allFav) {
      await repo.removeVersesFromCollection(favId, ids);
    } else {
      await repo.addVersesToCollection(favId, ids);
    }
    ref.invalidate(collectionsProvider);
    ref.invalidate(collectionVersesProvider(favId));
    ref.invalidate(chapterFavoritesProvider(chapterRef));
    if (!mounted) return;
    _snack(allFav ? 'Quitado de Favoritos' : 'Guardado en Favoritos');
  }

  Future<void> _addToPlaylist() async {
    final ids = _selectedIds.toList();
    final name = await showAddToPlaylistSheet(context, ref, ids);
    if (name == null || !mounted) return;
    _snack('Añadido a "$name"');
  }

  String _buildSelectionText() {
    final verses =
        ref
            .read(chapterProvider(ChapterRef(widget.bookId, widget.chapter)))
            .valueOrNull ??
        const <Verse>[];
    final book = ref.read(bookProvider(widget.bookId)).valueOrNull;
    final selected = verses.where((v) => _selectedIds.contains(v.id)).toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    if (selected.isEmpty || book == null) return '';
    final nums = selected.map((v) => v.verse).toList();
    final ref0 = nums.length == 1
        ? '${book.name} ${widget.chapter}:${nums.first}'
        : '${book.name} ${widget.chapter}:${nums.first}-${nums.last}';
    // Incluye el número de cada versículo en el texto.
    final body = selected.map((v) => '${v.verse} ${v.text}').join('\n');
    return '$body\n— $ref0 (RV1960)';
  }

  Future<void> _copySelection() async {
    final text = _buildSelectionText();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _snack('Copiado al portapapeles');
  }

  Future<void> _shareSelection() async {
    final text = _buildSelectionText();
    if (text.isEmpty) return;
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _snack('Copiado al portapapeles');
    }
  }

  Future<void> _applyColor() async {
    final ids = _selectedIds.toList();
    final choice = await _showColorPicker();
    if (choice == null || !mounted) return;
    final repo = await ref.read(repositoryProvider.future);
    if (choice == -1) {
      await repo.removeHighlights(ids);
    } else {
      await repo.setHighlight(ids, choice);
    }
    ref.invalidate(
      chapterHighlightsProvider(ChapterRef(widget.bookId, widget.chapter)),
    );
    ref.invalidate(highlightCountsProvider);
    ref.invalidate(versesByColorProvider);
    if (!mounted) return;
    _snack(choice == -1 ? 'Color quitado' : 'Versículos resaltados');
  }

  Future<int?> _showColorPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COLOR',
                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                  color: colors.inkSoft,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < highlightSwatches.length; i++)
                    Tooltip(
                      message: highlightSwatches[i].name,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, i),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: highlightColorFor(i, isDark),
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.divider),
                          ),
                        ),
                      ),
                    ),
                  Tooltip(
                    message: 'Quitar color',
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, -1),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.divider),
                        ),
                        child: Icon(
                          Icons.format_color_reset_outlined,
                          size: 20,
                          color: colors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1300),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(
      chapterProvider(ChapterRef(widget.bookId, widget.chapter)),
    );
    final bookAsync = ref.watch(bookProvider(widget.bookId));
    final scale = ref.watch(fontScaleProvider);
    final headings = ref
        .watch(
          chapterHeadingsProvider(ChapterRef(widget.bookId, widget.chapter)),
        )
        .maybeWhen(data: (m) => m, orElse: () => const <int, String>{});
    final highlights = ref
        .watch(
          chapterHighlightsProvider(ChapterRef(widget.bookId, widget.chapter)),
        )
        .maybeWhen(data: (m) => m, orElse: () => const <int, int>{});
    final favoriteIds = ref
        .watch(
          chapterFavoritesProvider(ChapterRef(widget.bookId, widget.chapter)),
        )
        .maybeWhen(data: (s) => s, orElse: () => const <int>{});
    final allFavorited =
        _selectedIds.isNotEmpty && _selectedIds.every(favoriteIds.contains);
    final books = ref.watch(booksProvider).valueOrNull;
    final colors = context.appColors;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        appBar: _selectionMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelection,
                ),
                title: Text(
                  '${_selectedIds.length} seleccionado'
                  '${_selectedIds.length == 1 ? '' : 's'}',
                ),
              )
            : AppBar(
                title: bookAsync.maybeWhen(
                  data: (b) => InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openChapters(b),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${b.name}  ${widget.chapter}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more,
                            size: 18,
                            color: colors.inkSoft,
                          ),
                        ],
                      ),
                    ),
                  ),
                  orElse: () => const Text(''),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Opciones de lectura',
                    onPressed: _showReadingSheet,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
        body: chapterAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (verses) {
            for (final v in verses) {
              _verseKeys.putIfAbsent(v.verse, () => GlobalKey());
            }
            _ensureGestures(verses);
            _verseNumbers = [for (final v in verses) v.verse];
            _maybeInitResume();
            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      GestureDetector(
                        key: _viewportKey,
                        onHorizontalDragEnd: (_selectionMode || books == null)
                            ? null
                            : (d) {
                                final v = d.primaryVelocity ?? 0;
                                // Deslizar a la derecha → capítulo anterior;
                                // a la izquierda → siguiente.
                                if (v > 300) {
                                  _swipeTo(books, -1);
                                } else if (v < -300) {
                                  _swipeTo(books, 1);
                                }
                              },
                        child: Scrollbar(
                          controller: _scroll,
                          child: SingleChildScrollView(
                            controller: _scroll,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 640,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    8,
                                    24,
                                    40,
                                  ),
                                  child: _ChapterText(
                                    book: bookAsync.asData?.value,
                                    verses: verses,
                                    headings: headings,
                                    highlights: highlights,
                                    verseKeys: _verseKeys,
                                    gestures: _gestures,
                                    selectedIds: _selectedIds,
                                    selectionMode: _selectionMode,
                                    highlightVerse: _activeHighlight,
                                    scale: scale,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_showResume && !_selectionMode)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 16,
                          child: Center(child: _ResumePill(onTap: _resume)),
                        ),
                      if (!_selectionMode && _verseNumbers.length > 1)
                        Positioned(
                          top: 8,
                          bottom: 8,
                          right: 0,
                          child: _VerseRail(
                            verses: _verseNumbers,
                            headings: headings,
                            activeVerse: _previewVerse ?? _activeVerse,
                            onPreview: (v) => setState(() => _previewVerse = v),
                            onJump: (v) {
                              setState(() => _previewVerse = null);
                              _jumpToVerse(v);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectionMode)
                  _SelectionBar(
                    favorited: allFavorited,
                    onCopy: _copySelection,
                    onShare: _shareSelection,
                    onFavorite: _toggleFavorites,
                    onColor: _applyColor,
                    onPlaylist: _addToPlaylist,
                  )
                else
                  _Footer(bookId: widget.bookId, chapter: widget.chapter),
              ],
            );
          },
        ),
      ),
    );
  }

  void _maybeInitResume() {
    if (_resumeInit) return;
    _resumeInit = true;
    if (_activeHighlight != null) return;
    final off = ref
        .read(scrollStoreProvider.notifier)
        .offsetFor(widget.bookId, widget.chapter);
    if (off == null || off < 120) return;
    void tryShow(int attempt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final max = _scroll.position.maxScrollExtent;
        if (max < 80) {
          // El contenido aún no se ha medido; reintenta unas pocas veces.
          if (attempt < 6) {
            Future.delayed(
              const Duration(milliseconds: 120),
              () => tryShow(attempt + 1),
            );
          }
          return;
        }
        setState(() {
          _resumeOffset = off.clamp(0.0, max);
          _showResume = true;
        });
      });
    }

    tryShow(0);
  }

  void _resume() {
    final target = _resumeOffset;
    if (target == null || !_scroll.hasClients) return;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
    setState(() => _showResume = false);
  }

  void _openChapters(Book book) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChaptersScreen(book: book)),
    );
  }

  void _showReadingSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ReadingOptionsSheet(),
    );
  }
}

class _Block {
  final String? title;
  final List<Verse> verses = [];
  _Block(this.title);
}

class _ChapterText extends StatelessWidget {
  final Book? book;
  final List<Verse> verses;
  final Map<int, String> headings;
  final Map<int, int> highlights; // verseId -> color index
  final Map<int, GlobalKey> verseKeys;
  final Map<int, _VerseGestures> gestures;
  final Set<int> selectedIds;
  final bool selectionMode;
  final int? highlightVerse;
  final double scale;

  const _ChapterText({
    required this.book,
    required this.verses,
    required this.headings,
    required this.highlights,
    required this.verseKeys,
    required this.gestures,
    required this.selectedIds,
    required this.selectionMode,
    required this.highlightVerse,
    required this.scale,
  });

  List<_Block> _toBlocks() {
    final blocks = <_Block>[];
    _Block? current;
    for (final v in verses) {
      final title = headings[v.verse];
      if (title != null || current == null) {
        current = _Block(title);
        blocks.add(current);
      }
      current.verses.add(v);
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final chapterNum = verses.isNotEmpty ? verses.first.chapter : 0;

    final body = theme.textTheme.bodyLarge!.copyWith(
      fontSize: 19 * scale,
      height: 1.9,
      letterSpacing: 0.1,
    );
    final numStyle = TextStyle(
      fontSize: 11 * scale,
      color: colors.accent,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.0,
      fontWeight: FontWeight.w700,
    );

    TextStyle? verseStyle(Verse v) {
      final selected = selectedIds.contains(v.id);
      final colorIdx = highlights[v.id];
      if (!selected && colorIdx == null) return null;
      // Selección: fondo de acento bien visible + subrayado sólido.
      // Resaltado de color (cuando NO está seleccionado): su tinte.
      Paint? bg;
      if (selected) {
        bg = Paint()
          ..color = colors.accent.withValues(alpha: isDark ? 0.34 : 0.24);
      } else if (colorIdx != null) {
        bg = Paint()
          ..color = highlightColorFor(
            colorIdx,
            isDark,
          ).withValues(alpha: isDark ? 0.45 : 0.40);
      }
      return TextStyle(
        background: bg,
        decoration: selected ? TextDecoration.underline : null,
        decorationColor: selected ? colors.accent : null,
        decorationThickness: selected ? 2.0 : null,
      );
    }

    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontSize: 18 * scale,
      fontWeight: FontWeight.w600,
      color: colors.accent,
      height: 1.3,
    );

    InlineSpan numberSpan(Verse v) => WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: Padding(
        padding: const EdgeInsets.only(right: 5, left: 2),
        child: Container(
          key: verseKeys[v.verse],
          decoration: highlightVerse == v.verse
              ? BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                )
              : null,
          padding: highlightVerse == v.verse
              ? const EdgeInsets.symmetric(horizontal: 3, vertical: 1)
              : EdgeInsets.zero,
          child: Text('${v.verse}', style: numStyle),
        ),
      ),
    );

    final blocks = _toBlocks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        if (book != null)
          Text(
            book!.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.inkSoft,
              letterSpacing: 2.4,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          '$chapterNum',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 48,
            color: colors.accent,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Container(width: 40, height: 2, color: colors.divider)),
        const SizedBox(height: 20),
        for (final block in blocks) ...[
          if (block.title != null)
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Text(block.title!, style: titleStyle),
            ),
          RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              style: body,
              children: [
                for (final v in block.verses) ...[
                  numberSpan(v),
                  TextSpan(
                    text: v.text,
                    recognizer: selectionMode
                        ? gestures[v.id]?.tap
                        : gestures[v.id]?.longPress,
                    style: verseStyle(v),
                  ),
                  const TextSpan(text: '  '),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ResumePill extends StatelessWidget {
  final VoidCallback onTap;
  const _ResumePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Material(
      color: colors.accent,
      borderRadius: BorderRadius.circular(24),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.south, size: 18, color: colors.bg),
              const SizedBox(width: 8),
              Text(
                'Continuar donde lo dejé',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.bg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final bool favorited;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final VoidCallback onColor;
  final VoidCallback onPlaylist;
  const _SelectionBar({
    required this.favorited,
    required this.onCopy,
    required this.onShare,
    required this.onFavorite,
    required this.onColor,
    required this.onPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
        color: theme.scaffoldBackgroundColor,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Action(
                icon: Icons.copy_outlined,
                label: 'Copiar',
                tooltip: 'Copiar al portapapeles',
                onTap: onCopy,
              ),
              _Action(
                icon: Icons.ios_share,
                label: 'Compartir',
                tooltip: 'Compartir',
                onTap: onShare,
              ),
              _Action(
                icon: favorited ? Icons.favorite : Icons.favorite_border,
                label: favorited ? 'Quitar' : 'Favorito',
                tooltip: favorited
                    ? 'Quitar de Favoritos'
                    : 'Guardar en Favoritos',
                onTap: onFavorite,
              ),
              _Action(
                icon: Icons.brush_outlined,
                label: 'Color',
                tooltip: 'Resaltar con un color',
                onTap: onColor,
              ),
              _Action(
                icon: Icons.playlist_add,
                label: 'Biblioteca',
                tooltip: 'Añadir a una biblioteca',
                onTap: onPlaylist,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: colors.accent),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.ink,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingOptionsSheet extends ConsumerWidget {
  const _ReadingOptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(fontScaleProvider);
    final notifier = ref.read(fontScaleProvider.notifier);
    final keepAwake = ref.watch(keepAwakeProvider);
    final theme = Theme.of(context);
    final colors = context.appColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TAMAÑO DE LETRA',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.inkSoft,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.divider),
              ),
              child: Text(
                'Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 19 * scale,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.text_decrease),
                  color: colors.ink,
                  tooltip: 'Reducir',
                  onPressed: () => notifier.set(scale - 0.1),
                ),
                Expanded(
                  child: Slider(
                    value: scale,
                    min: FontScaleNotifier.minScale,
                    max: FontScaleNotifier.maxScale,
                    divisions: 10,
                    activeColor: colors.accent,
                    inactiveColor: colors.divider,
                    label: '${(scale * 100).round()}%',
                    onChanged: notifier.set,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase),
                  color: colors.ink,
                  tooltip: 'Aumentar',
                  onPressed: () => notifier.set(scale + 0.1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.lightbulb_outline, color: colors.inkSoft),
              title: const Text('Mantener pantalla encendida'),
              subtitle: Text(
                'Mientras lees, la pantalla no se apaga',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkSoft,
                ),
              ),
              value: keepAwake,
              onChanged: (v) {
                ref.read(keepAwakeProvider.notifier).set(v);
                WakelockPlus.toggle(enable: v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  final int bookId;
  final int chapter;
  const _Footer({required this.bookId, required this.chapter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final colors = context.appColors;
    final theme = Theme.of(context);
    return booksAsync.maybeWhen(
      data: (books) {
        final cur = books.firstWhere((b) => b.id == bookId);
        final prev = _previousChapter(books, cur, chapter);
        final next = _nextChapter(books, cur, chapter);
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.divider)),
            color: theme.scaffoldBackgroundColor,
          ),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavButton(
                          label: prev == null
                              ? '—'
                              : (prev.$1.id == cur.id
                                    ? 'Cap. ${prev.$2}'
                                    : '${prev.$1.abbr} ${prev.$2}'),
                          icon: Icons.arrow_back,
                          onTap: prev == null
                              ? null
                              : () => _go(context, prev.$1.id, prev.$2, false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _NavButton(
                          label: next == null
                              ? '—'
                              : (next.$1.id == cur.id
                                    ? 'Cap. ${next.$2}'
                                    : '${next.$1.abbr} ${next.$2}'),
                          icon: Icons.arrow_forward,
                          iconRight: true,
                          onTap: next == null
                              ? null
                              : () => _go(context, next.$1.id, next.$2, true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _go(BuildContext context, int b, int c, bool forward) {
    Navigator.of(context).pushReplacement(
      chapterRoute(
        ReaderScreen(bookId: b, chapter: c),
        forward: forward,
      ),
    );
  }

  (Book, int)? _previousChapter(List<Book> books, Book cur, int ch) {
    if (ch > 1) return (cur, ch - 1);
    final idx = books.indexOf(cur);
    if (idx <= 0) return null;
    final prev = books[idx - 1];
    return (prev, prev.chapterCount);
  }

  (Book, int)? _nextChapter(List<Book> books, Book cur, int ch) {
    if (ch < cur.chapterCount) return (cur, ch + 1);
    final idx = books.indexOf(cur);
    if (idx == books.length - 1) return null;
    final next = books[idx + 1];
    return (next, 1);
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconRight;
  final VoidCallback? onTap;
  const _NavButton({
    required this.label,
    required this.icon,
    this.iconRight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final c = enabled ? colors.ink : colors.inkSoft.withValues(alpha: 0.4);
    final children = <Widget>[
      Icon(icon, size: 18, color: c),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(color: c),
        ),
      ),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: iconRight ? children.reversed.toList() : children,
          ),
        ),
      ),
    );
  }
}

/// Tira vertical de navegación de versículos (derecha). Comprime todos los
/// versículos para caber siempre; al deslizar resalta con un efecto "lupa"
/// y muestra el título/número, y salta solo al soltar dentro de la tira.
class _VerseRail extends StatefulWidget {
  final List<int> verses;
  final Map<int, String> headings; // verso -> título (inicio de grupo)
  final int? activeVerse;
  final ValueChanged<int?> onPreview;
  final ValueChanged<int> onJump;

  const _VerseRail({
    required this.verses,
    required this.headings,
    required this.activeVerse,
    required this.onPreview,
    required this.onJump,
  });

  @override
  State<_VerseRail> createState() => _VerseRailState();
}

class _VerseRailState extends State<_VerseRail> {
  static const double _w = 38;
  double? _y;
  double _h = 0;

  int _indexAt(double y) => (y / _h * widget.verses.length)
      .clamp(0, widget.verses.length - 1)
      .floor();

  Offset _toLocal(BuildContext ctx, Offset global) {
    final box = ctx.findRenderObject() as RenderBox;
    return box.globalToLocal(global);
  }

  bool _inside(Offset local) =>
      _h > 0 &&
      local.dx >= -10 &&
      local.dx <= _w &&
      local.dy >= 0 &&
      local.dy <= _h;

  void _track(Offset local) {
    if (!_inside(local)) {
      if (_y != null) {
        setState(() => _y = null);
        widget.onPreview(null);
      }
      return;
    }
    final idx = _indexAt(local.dy);
    setState(() => _y = local.dy);
    widget.onPreview(widget.verses[idx]);
  }

  void _commit(Offset local) {
    if (_inside(local) && _y != null) {
      widget.onJump(widget.verses[_indexAt(local.dy)]);
    } else {
      widget.onPreview(null);
    }
    setState(() => _y = null);
  }

  /// Título del grupo (perícopa) al que pertenece el versículo previsualizado.
  String? _groupTitle(int verseNumber) {
    String? title;
    for (final v in widget.verses) {
      if (widget.headings.containsKey(v)) title = widget.headings[v];
      if (v == verseNumber) break;
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    final groupStarts = <int>{};
    for (var i = 0; i < widget.verses.length; i++) {
      if (widget.headings.containsKey(widget.verses[i])) groupStarts.add(i);
    }

    int? activeIndex;
    if (_y != null) {
      activeIndex = _indexAt(_y!);
    } else if (widget.activeVerse != null) {
      final i = widget.verses.indexOf(widget.activeVerse!);
      if (i >= 0) activeIndex = i;
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        _h = constraints.maxHeight;
        final previewVerse = _y != null ? widget.verses[_indexAt(_y!)] : null;
        final title = previewVerse != null ? _groupTitle(previewVerse) : null;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _track(_toLocal(ctx, e.position)),
          onPointerMove: (e) => _track(_toLocal(ctx, e.position)),
          onPointerUp: (e) => _commit(_toLocal(ctx, e.position)),
          onPointerCancel: (_) {
            setState(() => _y = null);
            widget.onPreview(null);
          },
          child: SizedBox(
            width: _w,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RailPainter(
                      count: widget.verses.length,
                      activeIndex: activeIndex,
                      previewY: _y,
                      groupStarts: groupStarts,
                      tickColor: colors.inkSoft.withValues(alpha: 0.45),
                      accent: colors.accent,
                    ),
                  ),
                ),
                if (previewVerse != null)
                  Positioned(
                    right: _w + 6,
                    top: (_y! - 24).clamp(0.0, _h - 48),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 230),
                      child: Material(
                        color: colors.surface,
                        elevation: 3,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (title != null)
                                Text(
                                  title,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              Text(
                                'Versículo $previewVerse',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.accent,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _RailPainter extends CustomPainter {
  final int count;
  final int? activeIndex;
  final double? previewY;
  final Set<int> groupStarts;
  final Color tickColor;
  final Color accent;

  _RailPainter({
    required this.count,
    required this.activeIndex,
    required this.previewY,
    required this.groupStarts,
    required this.tickColor,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final h = size.height;
    final w = size.width;
    final p = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final cy = (i + 0.5) / count * h;
      var len = 9.0;
      if (previewY != null) {
        final d = (cy - previewY!).abs();
        len += 18 * math.exp(-(d * d) / (2 * 17 * 17)); // lupa
      }
      final isActive = i == activeIndex;
      if (isActive) {
        if (len < 22) len = 22;
        p
          ..color = accent
          ..strokeWidth = 2.6;
      } else if (groupStarts.contains(i)) {
        p
          ..color = accent.withValues(alpha: 0.55)
          ..strokeWidth = 2.0;
      } else {
        p
          ..color = tickColor
          ..strokeWidth = 1.4;
      }
      canvas.drawLine(Offset(w - len, cy), Offset(w - 2, cy), p);
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.activeIndex != activeIndex ||
      old.previewY != previewY ||
      old.count != count ||
      old.accent != accent;
}

/// Transición de capítulo con dirección: siguiente entra desde la derecha,
/// anterior desde la izquierda.
Route<T> chapterRoute<T>(Widget page, {required bool forward}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, animation, _, child) {
      final begin = forward ? const Offset(1, 0) : const Offset(-1, 0);
      return SlideTransition(
        position: animation.drive(
          Tween(
            begin: begin,
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      );
    },
  );
}
