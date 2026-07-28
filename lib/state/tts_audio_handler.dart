import 'package:audio_service/audio_service.dart';

/// Puente entre la lectura en voz alta ([TtsController]) y el sistema.
///
/// No sintetiza voz por sí mismo: mantiene vivo el proceso en segundo plano
/// (servicio en primer plano de Android) y muestra la notificación de medios
/// con controles (anterior, reproducir/pausar, siguiente, detener). Los toques
/// en la notificación / pantalla de bloqueo se reenvían al controlador
/// mediante los callbacks que este le conecta.
class TtsAudioHandler extends BaseAudioHandler {
  Future<void> Function()? onPlayCb;
  Future<void> Function()? onPauseCb;
  Future<void> Function()? onStopCb;
  Future<void> Function()? onNextCb;
  Future<void> Function()? onPreviousCb;

  @override
  Future<void> play() async => onPlayCb == null ? null : await onPlayCb!();

  @override
  Future<void> pause() async => onPauseCb == null ? null : await onPauseCb!();

  @override
  Future<void> stop() async => onStopCb == null ? null : await onStopCb!();

  @override
  Future<void> skipToNext() async =>
      onNextCb == null ? null : await onNextCb!();

  @override
  Future<void> skipToPrevious() async =>
      onPreviousCb == null ? null : await onPreviousCb!();

  /// Refleja el estado del [TtsController] en la notificación / lock screen.
  void publish({
    required bool active,
    required bool playing,
    required String title,
    required String subtitle,
  }) {
    if (!active) {
      playbackState.add(
        playbackState.value.copyWith(
          controls: const [],
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      mediaItem.add(null); // cierra la notificación
      return;
    }
    mediaItem.add(
      MediaItem(id: 'tts', title: title, artist: subtitle, album: 'La Biblia'),
    );
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
      ),
    );
  }
}
