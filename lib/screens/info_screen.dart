import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/books.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';

class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final progress = ref.watch(readingProgressProvider);
    final seconds = ref.watch(readingSecondsProvider).valueOrNull ?? 0;
    final saved = ref.watch(savedVerseCountProvider).valueOrNull ?? 0;
    final highlights = ref
        .watch(highlightCountsProvider)
        .valueOrNull
        ?.values
        .fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu lectura'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reiniciar estadísticas',
            onPressed: () => _confirmReset(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (books) {
          final totalChapters = books.fold<int>(
            0,
            (a, b) => a + b.chapterCount,
          );
          final chaptersRead = progress.totalRead;
          final booksDone = books
              .where((b) => progress.readCountFor(b.id) >= b.chapterCount)
              .length;
          final pct = totalChapters == 0
              ? 0
              : (chaptersRead / totalChapters * 100).round();
          final streak = _streak(progress.days);

          final ot = books.where((b) => b.testament == testamentOld).toList();
          final nt = books.where((b) => b.testament == testamentNew).toList();

          // Libro y capítulo más leídos (contando relecturas).
          Book? topBook;
          var topBookCount = 0;
          for (final b in books) {
            final n = progress.visitsForBook(b.id);
            if (n > topBookCount) {
              topBookCount = n;
              topBook = b;
            }
          }
          String? topChapterLabel;
          var topChapterCount = 0;
          progress.visits.forEach((k, v) {
            if (v > topChapterCount) {
              topChapterCount = v;
              topChapterLabel = k;
            }
          });
          String? topChapterText;
          if (topChapterLabel != null) {
            final parts = topChapterLabel!.split(':');
            final b = books.firstWhere(
              (x) => x.id == int.parse(parts[0]),
              orElse: () => books.first,
            );
            topChapterText = '${b.name} ${parts[1]}';
          }

          // Libros casi terminados (≥ 80 %, sin completar) para animar.
          final almost =
              books.where((b) {
                final r = progress.readCountFor(b.id);
                return r > 0 && r < b.chapterCount && r / b.chapterCount >= 0.8;
              }).toList()..sort(
                (a, b) => (b.chapterCount - progress.readCountFor(b.id))
                    .compareTo(a.chapterCount - progress.readCountFor(a.id)),
              );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        value: '$booksDone/66',
                        label: 'Libros completos',
                        icon: Icons.menu_book_outlined,
                      ),
                      _StatCard(
                        value: '$chaptersRead/$totalChapters',
                        label: 'Capítulos leídos · $pct%',
                        icon: Icons.bookmark_added_outlined,
                      ),
                      _StatCard(
                        value: _formatTime(seconds),
                        label: 'Tiempo de lectura',
                        icon: Icons.schedule,
                      ),
                      _StatCard(
                        value: '$streak ${streak == 1 ? 'día' : 'días'}',
                        label: 'Racha · ${progress.days.length} en total',
                        icon: Icons.local_fire_department_outlined,
                      ),
                      _StatCard(
                        value: '$saved',
                        label: 'Versículos guardados',
                        icon: Icons.favorite_border,
                      ),
                      _StatCard(
                        value: '${highlights ?? 0}',
                        label: 'Resaltados',
                        icon: Icons.brush_outlined,
                      ),
                    ],
                  ),
                  if (topBook != null) ...[
                    const SizedBox(height: 20),
                    _WideStat(
                      icon: Icons.auto_stories_outlined,
                      label: 'Libro más leído',
                      value: topBook.name,
                      sub:
                          '$topBookCount ${topBookCount == 1 ? 'lectura' : 'lecturas'}',
                    ),
                    if (topChapterText != null) ...[
                      const SizedBox(height: 12),
                      _WideStat(
                        icon: Icons.repeat,
                        label: 'Capítulo más leído',
                        value: topChapterText,
                        sub:
                            '$topChapterCount ${topChapterCount == 1 ? 'vez' : 'veces'}',
                      ),
                    ],
                  ],
                  const SizedBox(height: 28),
                  _sectionLabel(context, 'DÍAS DE LECTURA'),
                  const SizedBox(height: 12),
                  _ReadingCalendar(days: progress.days),
                  if (almost.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _sectionLabel(context, 'TE FALTA POCO'),
                    const SizedBox(height: 4),
                    for (final b in almost)
                      _BookProgress(book: b, read: progress.readCountFor(b.id)),
                  ],
                  if (progress.completed.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _sectionLabel(context, 'TERMINADOS · PARA EL RECUERDO'),
                    const SizedBox(height: 4),
                    for (final e
                        in (progress.completed.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value))))
                      _CompletedRow(
                        name: books
                            .firstWhere(
                              (x) => x.id == e.key,
                              orElse: () => books.first,
                            )
                            .name,
                        date: _prettyDate(e.value),
                      ),
                  ],
                  const SizedBox(height: 28),
                  _sectionLabel(context, 'PROGRESO POR LIBRO'),
                  const SizedBox(height: 4),
                  _sectionLabel(context, 'Antiguo Testamento', small: true),
                  for (final b in ot)
                    _BookProgress(book: b, read: progress.readCountFor(b.id)),
                  const SizedBox(height: 12),
                  _sectionLabel(context, 'Nuevo Testamento', small: true),
                  for (final b in nt)
                    _BookProgress(book: b, read: progress.readCountFor(b.id)),
                  const SizedBox(height: 32),
                  _Dedication(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(
    BuildContext context,
    String text, {
    bool small = false,
  }) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, small ? 14 : 0, 4, small ? 6 : 0),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: small ? colors.accent : colors.inkSoft,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  String _prettyDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final m = int.tryParse(parts[1]) ?? 1;
    return '${int.parse(parts[2])} ${_months[(m - 1).clamp(0, 11)]} ${parts[0]}';
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reiniciar los números? 📊'),
        content: const Text(
          'Adiós racha, tiempo y libros terminados, y de ahí no se vuelve '
          '(tus bibliotecas y resaltados se quedan).\n\n'
          'Borrón y cuenta nueva, que a veces hace falta… pero, '
          '¿respaldaste primero? Es por si las moscas. 😇',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mejor no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dale, reinicia'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(readingProgressProvider.notifier).reset();
    ref.invalidate(readingSecondsProvider);
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '<1m';
  }

  int _streak(Set<String> days) {
    if (days.isEmpty) return 0;
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    var day = DateTime.now();
    if (!days.contains(fmt(day))) {
      day = day.subtract(const Duration(days: 1)); // gracia hasta fin del día
    }
    var s = 0;
    while (days.contains(fmt(day))) {
      s++;
      day = day.subtract(const Duration(days: 1));
    }
    return s;
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      width: 162,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.displayMedium?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _WideStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  const _WideStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.inkSoft,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.titleLarge),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.accent),
          ),
        ],
      ),
    );
  }
}

class _ReadingCalendar extends StatelessWidget {
  final Set<String> days;
  const _ReadingCalendar({required this.days});

  static const _weeks = 18;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final today = DateTime.now();
    final wd = today.weekday % 7; // 0 = domingo

    final columns = <Widget>[];
    for (var c = _weeks - 1; c >= 0; c--) {
      final cells = <Widget>[];
      for (var r = 0; r < 7; r++) {
        final offset = (wd - r) + 7 * c;
        Color color;
        if (offset < 0) {
          color = Colors.transparent; // futuro
        } else {
          final date = today.subtract(Duration(days: offset));
          color = days.contains(_fmt(date))
              ? colors.accent
              : colors.divider.withValues(alpha: 0.6);
        }
        cells.add(
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }
      columns.add(Column(children: cells));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(children: columns),
        ),
        const SizedBox(height: 8),
        Text(
          'Últimas $_weeks semanas',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
        ),
      ],
    );
  }
}

class _CompletedRow extends StatelessWidget {
  final String name;
  final String date;
  const _CompletedRow({required this.name, required this.date});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 18, color: colors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
          ),
          Text(
            date,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _BookProgress extends StatelessWidget {
  final Book book;
  final int read;
  const _BookProgress({required this.book, required this.read});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final total = book.chapterCount;
    final frac = total == 0 ? 0.0 : (read / total).clamp(0.0, 1.0);
    final done = read >= total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              book.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: done ? colors.accent : colors.ink,
                fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 6,
                backgroundColor: colors.divider,
                valueColor: AlwaysStoppedAnimation(colors.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(
              '$read/$total',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkSoft,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dedication extends StatefulWidget {
  @override
  State<_Dedication> createState() => _DedicationState();
}

class _DedicationState extends State<_Dedication> {
  // Easter egg: el corazón cambia de color cada vez que lo tocas.
  static const _heartColors = [
    Color(0xFFE0457B), // rosa
    Color(0xFFE53935), // rojo
    Color(0xFFEF6C00), // naranja
    Color(0xFFF9A825), // ámbar
    Color(0xFF43A047), // verde
    Color(0xFF1E88E5), // azul
    Color(0xFF8E24AA), // morado
  ];
  int _heart = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Column(
      children: [
        Divider(color: colors.divider),
        const SizedBox(height: 18),
        Icon(Icons.favorite, size: 18, color: colors.accent),
        const SizedBox(height: 14),
        Text(
          'Sin anuncios, sin internet y sin pedirte reseña '
          'cada tres versículos.\n'
          'Si encuentras un bug, no era un bug: era una señal. 🙃',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.inkSoft,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Hecha por Kevin Carrera.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 2),
        Text(
          'kevin.ccdo@gmail.com',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Y sí, a ti que estás leyendo esto: te amo ',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () =>
                  setState(() => _heart = (_heart + 1) % _heartColors.length),
              child: Icon(
                Icons.favorite,
                size: 20,
                color: _heartColors[_heart],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => launchUrl(
            Uri.parse('https://github.com/yt-kevincarrera/minimal-bible'),
            mode: LaunchMode.externalApplication,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 16, color: colors.inkSoft),
                const SizedBox(width: 8),
                Text(
                  'Código abierto en GitHub',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.accent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
