import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/models.dart';
import 'providers.dart';

/// Velocidad de lectura en voz alta, en "equis" (1.0 = normal). Persistida.
/// El motor del sistema usa un rango 0.0–1.0 donde ~0.5 suena normal en
/// Android, así que mapeamos: engine = appRate * 0.5.
class TtsRateNotifier extends Notifier<double> {
  static const _key = 'tts_rate';
  static const minRate = 0.5;
  static const maxRate = 2.0;

  @override
  double build() => 1.0;

  Future<void> load() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final v = prefs.getDouble(_key);
    if (v != null) state = v.clamp(minRate, maxRate);
  }

  Future<void> set(double v) async {
    final clamped = v.clamp(minRate, maxRate);
    if (clamped == state) return;
    state = clamped;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setDouble(_key, clamped);
  }
}

final ttsRateProvider = NotifierProvider<TtsRateNotifier, double>(
  TtsRateNotifier.new,
);

enum TtsStatus { idle, playing, paused }

/// Estado de la lectura en voz alta. Cuando [status] != idle, [bookId]/[chapter]
/// indican qué capítulo se está leyendo y [verse] el versículo actual.
class TtsState {
  final TtsStatus status;
  final int? bookId;
  final int? chapter;
  final int? verse;

  const TtsState({
    this.status = TtsStatus.idle,
    this.bookId,
    this.chapter,
    this.verse,
  });

  bool get isActive => status != TtsStatus.idle;

  bool isFor(int bookId, int chapter) =>
      isActive && this.bookId == bookId && this.chapter == chapter;

  TtsState copyWith({TtsStatus? status, int? verse}) => TtsState(
    status: status ?? this.status,
    bookId: bookId,
    chapter: chapter,
    verse: verse ?? this.verse,
  );
}

/// Controla la síntesis de voz del sistema (flutter_tts). Lee un capítulo
/// versículo por versículo; avanza solo cuando el motor termina cada uno.
class TtsController extends Notifier<TtsState> {
  FlutterTts? _tts;
  List<Verse> _queue = const [];
  int _index = 0;
  bool _ready = false;

  @override
  TtsState build() {
    ref.onDispose(() => _tts?.stop());
    return const TtsState();
  }

  Future<void> _ensure() async {
    if (_tts != null) return;
    final tts = FlutterTts();
    // Elige una voz en español disponible en el dispositivo.
    try {
      final ok = await tts.isLanguageAvailable('es-ES');
      if (ok == true) {
        await tts.setLanguage('es-ES');
      } else {
        final langs = (await tts.getLanguages as List)
            .map((e) => e.toString())
            .toList();
        final es = langs.firstWhere(
          (l) => l.toLowerCase().startsWith('es'),
          orElse: () => 'es-ES',
        );
        await tts.setLanguage(es);
      }
    } catch (_) {
      // Si la consulta falla, intentamos igual con es-ES.
      try {
        await tts.setLanguage('es-ES');
      } catch (_) {}
    }
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await tts.setSpeechRate(_engineRate(ref.read(ttsRateProvider)));
    tts.setCompletionHandler(_onComplete);
    tts.setErrorHandler((_) => _onError());
    _tts = tts;
    _ready = true;
  }

  double _engineRate(double appRate) => (appRate * 0.5).clamp(0.0, 1.0);

  static const _platform = MethodChannel('minimal_bible/tts');

  /// En Android podemos llevar al usuario a instalar la voz del sistema.
  bool get canOpenVoiceSettings =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// ¿Hay alguna voz en español instalada y usable? `isLanguageAvailable`
  /// devuelve false cuando el idioma existe pero faltan los datos de voz, que
  /// es justo el caso en el que queremos mandar a ajustes.
  Future<bool> spanishAvailable() async {
    final tts = _tts ?? FlutterTts();
    try {
      for (final l in const ['es-ES', 'es-US', 'es-MX', 'es-419', 'es']) {
        if (await tts.isLanguageAvailable(l) == true) return true;
      }
      return false;
    } catch (_) {
      return true; // si no se puede verificar, no bloqueamos la lectura
    }
  }

  /// Abre los ajustes de Texto a voz del sistema (Android).
  Future<void> openVoiceSettings() async {
    try {
      await _platform.invokeMethod('openTtsSettings');
    } catch (_) {
      // Sin canal nativo (otras plataformas): no-op.
    }
  }

  /// Empieza a leer [verses] del capítulo dado, desde [fromIndex].
  Future<void> start(
    int bookId,
    int chapter,
    List<Verse> verses, {
    int fromIndex = 0,
  }) async {
    if (verses.isEmpty) return;
    await _ensure();
    _queue = verses;
    _index = fromIndex.clamp(0, verses.length - 1);
    state = TtsState(
      status: TtsStatus.playing,
      bookId: bookId,
      chapter: chapter,
      verse: _queue[_index].verse,
    );
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    final tts = _tts;
    if (tts == null) return;
    if (_index >= _queue.length) {
      await stop();
      return;
    }
    state = state.copyWith(
      status: TtsStatus.playing,
      verse: _queue[_index].verse,
    );
    try {
      await tts.speak(_queue[_index].text);
    } catch (_) {
      _onError();
    }
  }

  // El motor terminó de leer un versículo: avanza al siguiente.
  void _onComplete() {
    if (state.status != TtsStatus.playing) return; // pausado/detenido
    _index++;
    if (_index >= _queue.length) {
      state = const TtsState(); // capítulo terminado
      return;
    }
    _speakCurrent();
  }

  void _onError() {
    state = const TtsState();
  }

  Future<void> pause() async {
    if (state.status != TtsStatus.playing) return;
    state = state.copyWith(status: TtsStatus.paused);
    await _tts?.stop(); // dispara cancelHandler, que ignoramos
  }

  Future<void> resume() async {
    if (state.status != TtsStatus.paused) return;
    await _speakCurrent(); // re-lee el versículo actual desde el inicio
  }

  Future<void> stop() async {
    state = const TtsState();
    await _tts?.stop();
  }

  Future<void> toggle() async {
    switch (state.status) {
      case TtsStatus.playing:
        await pause();
      case TtsStatus.paused:
        await resume();
      case TtsStatus.idle:
        break;
    }
  }

  /// Cambia la velocidad; si está leyendo, aplica el cambio al instante
  /// reiniciando el versículo en curso.
  Future<void> setRate(double appRate) async {
    await ref.read(ttsRateProvider.notifier).set(appRate);
    if (!_ready) return;
    await _tts?.setSpeechRate(_engineRate(appRate));
    if (state.status == TtsStatus.playing) {
      await _tts?.stop();
      await _speakCurrent();
    }
  }
}

final ttsControllerProvider = NotifierProvider<TtsController, TtsState>(
  TtsController.new,
);
