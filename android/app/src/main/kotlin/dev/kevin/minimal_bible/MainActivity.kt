package dev.kevin.minimal_bible

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "minimal_bible/tts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openTtsSettings" -> result.success(openTtsSettings())
                    else -> result.notImplemented()
                }
            }
    }

    // Abre, en orden de preferencia: la descarga de datos de voz, la pantalla
    // de "Texto a voz", o los ajustes generales. Devuelve true si abrió algo.
    private fun openTtsSettings(): Boolean {
        val candidates = listOf(
            Intent("android.speech.tts.engine.INSTALL_TTS_DATA"),
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(Settings.ACTION_SETTINGS),
        )
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Prueba el siguiente.
            }
        }
        return false
    }
}
