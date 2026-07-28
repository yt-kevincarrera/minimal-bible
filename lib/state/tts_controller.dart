import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/models.dart';
import 'providers.dart';
import 'tts_audio_handler.dart';

/// Handler de medios para segundo plano. Se sobreescribe en `main()` con la
/// instancia creada por `AudioService.init` (o una simple en plataformas sin
/// soporte).
final ttsAudioHandlerProvider = Provider<TtsAudioHandler>(
  (ref) => throw UnimplementedError('ttsAudioHandlerProvider sin inicializar'),
);

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
/// [index] es la posición (0-based) en el capítulo y [total] cuántos versículos
/// tiene, para mostrar el progreso "versículo X de Y".
class TtsState {
  final TtsStatus status;
  final int? bookId;
  final int? chapter;
  final int? verse;
  final int index;
  final int total;

  const TtsState({
    this.status = TtsStatus.idle,
    this.bookId,
    this.chapter,
    this.verse,
    this.index = 0,
    this.total = 0,
  });

  bool get isActive => status != TtsStatus.idle;

  bool isFor(int bookId, int chapter) =>
      isActive && this.bookId == bookId && this.chapter == chapter;

  /// Progreso 0..1 dentro del capítulo, por número de versículo.
  double get progress => total <= 0 ? 0 : ((index + 1) / total).clamp(0.0, 1.0);

  TtsState copyWith({TtsStatus? status, int? verse, int? index}) => TtsState(
    status: status ?? this.status,
    bookId: bookId,
    chapter: chapter,
    verse: verse ?? this.verse,
    index: index ?? this.index,
    total: total,
  );
}

/// Controla la síntesis de voz del sistema (flutter_tts). Lee un capítulo
/// versículo por versículo; avanza solo cuando el motor termina cada uno.
class TtsController extends Notifier<TtsState> {
  FlutterTts? _tts;
  List<Verse> _queue = const [];
  int _index = 0;
  bool _ready = false;

  // Para reanudar a mitad de versículo. El motor solo puede empezar una
  // locución desde el principio del texto que se le pasa, así que al pausar
  // recordamos por dónde iba y al reanudar hablamos solo el resto.
  int _spokenBase = 0; // offset (en el texto del versículo) donde empezó la locución actual
  int _lastWordStart = 0; // inicio de la palabra en curso, relativo a la locución
  int _pausedChar = 0; // offset absoluto donde se pausó

  bool _mediaWired = false;

  @override
  TtsState build() {
    ref.onDispose(() => _tts?.stop());
    // Refleja cada cambio de estado en la notificación de medios.
    listenSelf((_, next) => _syncMedia(next));
    return const TtsState();
  }

  /// Actualiza la notificación / pantalla de bloqueo con el estado actual.
  void _syncMedia(TtsState s) {
    final handler = ref.read(ttsAudioHandlerProvider);
    if (!s.isActive) {
      handler.publish(active: false, playing: false, title: '', subtitle: '');
      return;
    }
    final books = ref.read(booksProvider).valueOrNull;
    final name = books
        ?.where((b) => b.id == s.bookId)
        .map((b) => b.name)
        .firstOrNull;
    final title = name != null ? '$name ${s.chapter}' : 'La Biblia';
    final subtitle = s.total > 0
        ? 'Versículo ${s.index + 1} de ${s.total}'
        : 'Reina-Valera 1960';
    handler.publish(
      active: true,
      playing: s.status == TtsStatus.playing,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Conecta los botones de la notificación con este controlador (una vez).
  void _wireMediaControls() {
    if (_mediaWired) return;
    _mediaWired = true;
    final handler = ref.read(ttsAudioHandlerProvider);
    handler.onPlayCb = resume;
    handler.onPauseCb = pause;
    handler.onStopCb = stop;
    handler.onNextCb = next;
    handler.onPreviousCb = previous;
  }

  /// ¿Se está leyendo en voz alta el capítulo indicado? Expone el estado de
  /// forma pública para no acceder a [state] desde fuera del notifier.
  bool isReadingChapter(int bookId, int chapter) =>
      state.isFor(bookId, chapter);

  Future<void> _ensure() async {
    if (_tts != null) return;
    // Categoría de audio "voz": enruta y gestiona el foco correctamente y
    // permite sonar en segundo plano.
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (_) {}
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
    // Sigue la palabra en curso para poder reanudar justo por ahí.
    tts.setProgressHandler((text, start, end, word) => _lastWordStart = start);
    _tts = tts;
    _ready = true;
    _wireMediaControls();
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
      index: _index,
      total: verses.length,
    );
    await _speakCurrent();
  }

  /// Habla el versículo actual, opcionalmente empezando en [fromChar]
  /// (para reanudar a mitad). No detiene el motor: usar [_restart] cuando el
  /// motor pueda estar sonando.
  Future<void> _speakCurrent({int fromChar = 0}) async {
    final tts = _tts;
    if (tts == null) return;
    if (_index >= _queue.length) {
      await _advanceChapter();
      return;
    }
    final full = _queue[_index].text;
    _spokenBase = fromChar.clamp(0, full.length);
    _lastWordStart = 0;
    state = state.copyWith(
      status: TtsStatus.playing,
      verse: _queue[_index].verse,
      index: _index,
    );
    try {
      await tts.speak(full.substring(_spokenBase));
    } catch (_) {
      _onError();
    }
  }

  /// Detiene la locución en curso y arranca de nuevo (versículo actual o
  /// [fromChar]). Se usa al saltar de versículo, reanudar o cambiar velocidad.
  Future<void> _restart({int fromChar = 0}) async {
    await _tts?.stop();
    await _speakCurrent(fromChar: fromChar);
  }

  // El motor terminó de leer un versículo: avanza al siguiente (o de capítulo).
  void _onComplete() {
    if (state.status != TtsStatus.playing) return; // pausado/detenido
    if (_index < _queue.length - 1) {
      _index++;
      _speakCurrent();
    } else {
      _advanceChapter(); // sigue leyendo el capítulo siguiente
    }
  }

  void _onError() {
    _resetPos();
    state = const TtsState();
  }

  void _resetPos() {
    _spokenBase = 0;
    _lastWordStart = 0;
    _pausedChar = 0;
  }

  /// Salta al siguiente versículo (o al primero del capítulo siguiente).
  Future<void> next() async {
    if (!state.isActive) return;
    if (_index < _queue.length - 1) {
      _index++;
      await _restart();
    } else {
      await _advanceChapter();
    }
  }

  /// Vuelve al versículo anterior (o reinicia el primero).
  Future<void> previous() async {
    if (!state.isActive) return;
    _index = (_index - 1).clamp(0, _queue.length - 1);
    await _restart();
  }

  /// Continúa leyendo el capítulo siguiente sin intervención. Al llegar al
  /// final de la Biblia, se detiene.
  Future<void> _advanceChapter() async {
    await _tts?.stop();
    final books = ref.read(booksProvider).valueOrNull;
    final bookId = state.bookId;
    final chapter = state.chapter;
    if (books == null || bookId == null || chapter == null) {
      await stop();
      return;
    }
    final target = _nextChapterOf(books, bookId, chapter);
    if (target == null) {
      await stop(); // fin de la Biblia
      return;
    }
    List<Verse> verses;
    try {
      verses = await ref.read(
        chapterProvider(ChapterRef(target.$1, target.$2)).future,
      );
    } catch (_) {
      await stop();
      return;
    }
    if (verses.isEmpty) {
      await stop();
      return;
    }
    _queue = verses;
    _index = 0;
    _resetPos();
    state = TtsState(
      status: TtsStatus.playing,
      bookId: target.$1,
      chapter: target.$2,
      verse: verses.first.verse,
      index: 0,
      total: verses.length,
    );
    await _speakCurrent();
  }

  /// (bookId, chapter) del capítulo que sigue, o null si es el último.
  (int, int)? _nextChapterOf(List<Book> books, int bookId, int chapter) {
    final idx = books.indexWhere((b) => b.id == bookId);
    if (idx < 0) return null;
    final cur = books[idx];
    if (chapter < cur.chapterCount) return (bookId, chapter + 1);
    if (idx == books.length - 1) return null;
    return (books[idx + 1].id, 1);
  }

  Future<void> pause() async {
    if (state.status != TtsStatus.playing) return;
    // Recuerda el inicio de la palabra en curso para reanudar justo ahí.
    _pausedChar = _spokenBase + _lastWordStart;
    state = state.copyWith(status: TtsStatus.paused);
    await _tts?.stop(); // dispara cancelHandler, que ignoramos
  }

  Future<void> resume() async {
    if (state.status != TtsStatus.paused) return;
    await _speakCurrent(fromChar: _pausedChar); // sigue donde se quedó
  }

  Future<void> stop() async {
    _resetPos();
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

  /// Cambia la velocidad; si está leyendo, aplica el cambio al instante sin
  /// reiniciar el versículo: continúa desde la palabra en curso.
  Future<void> setRate(double appRate) async {
    await ref.read(ttsRateProvider.notifier).set(appRate);
    if (!_ready) return;
    await _tts?.setSpeechRate(_engineRate(appRate));
    if (state.status == TtsStatus.playing) {
      await _restart(fromChar: _spokenBase + _lastWordStart);
    }
  }
}

final ttsControllerProvider = NotifierProvider<TtsController, TtsState>(
  TtsController.new,
);
