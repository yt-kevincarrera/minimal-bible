import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'state/providers.dart';
import 'state/tts_controller.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: MinimalBibleApp()));
}

class MinimalBibleApp extends ConsumerWidget {
  const MinimalBibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentIndex = ref.watch(accentProvider);
    final palette =
        accentPalettes[accentIndex.clamp(0, accentPalettes.length - 1)];
    return MaterialApp(
      title: 'La Biblia',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(palette),
      darkTheme: buildDarkTheme(palette),
      themeMode: themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeModeProvider.notifier).load();
      ref.read(readingProgressProvider.notifier).load();
      ref.read(fontScaleProvider.notifier).load();
      ref.read(accentProvider.notifier).load();
      ref.read(tabIndexProvider.notifier).load();
      ref.read(scrollStoreProvider.notifier).load();
      ref.read(keepAwakeProvider.notifier).load();
      ref.read(ttsRateProvider.notifier).load();
      ref.read(lineHeightProvider.notifier).load();
      ref.read(recentSearchesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(databaseProvider);
    return dbAsync.when(
      data: (_) => const HomeScreen(),
      loading: () => const _BootScreen(),
      error: (e, st) => _ErrorScreen(message: e.toString()),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'La Biblia',
              style: TextStyle(
                fontFamily: 'CrimsonPro',
                fontSize: 36,
                fontWeight: FontWeight.w500,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Reina-Valera 1960',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                letterSpacing: 1.5,
                color: colors.inkSoft,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No se pudo abrir la base de datos.\n$message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
