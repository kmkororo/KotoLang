package com.kmkor.kotolang

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared from another app.
 *
 * Copying a long AI reply by dragging selection handles is close to impossible
 * on a phone, so KotoLang also registers as a share target: the reply can be
 * sent straight here from the assistant's own app, whole, with no clipboard
 * involved at all.
 *
 * The text is held until Dart asks for it, because a cold start delivers the
 * intent long before any Flutter code is listening.
 *
 * Two more small things live here because Flutter does not reach them:
 *
 * - **What cuts the listening short.** Headphones pulled out, or the sound
 *   taken by something else (a call, another app). A line half-heard on a
 *   train is not a line missed, so the question stops and waits.
 * - **The taps under the voice.** The vibration motor, for lengths in
 *   milliseconds. This one needs the VIBRATE permission, the app's only one;
 *   the screen's own haptics go silent wherever touch feedback is off.
 */
class MainActivity : FlutterActivity() {
    private var pendingText: String? = null
    private var channel: MethodChannel? = null
    private var audioChannel: MethodChannel? = null

    private var noisy: BroadcastReceiver? = null
    private var focusRequest: AudioFocusRequest? = null
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        // Ducking for a notification is not an interruption; losing the sound
        // is. A call or another app playing takes it.
        if (change == AudioManager.AUDIOFOCUS_LOSS ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
        ) {
            audioChannel?.invokeMethod("interrupted", "focus")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingText = extractSharedText(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Consumed rather than peeked at: the same share must not be
                    // offered again on the next resume.
                    "takeSharedText" -> {
                        val text = pendingText
                        pendingText = null
                        result.success(text)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        audioChannel = MethodChannel(messenger, AUDIO_CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "hold" -> {
                        holdAudio()
                        result.success(null)
                    }
                    "release" -> {
                        releaseAudio()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(messenger, FEEL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> result.success(
                    vibrate((call.arguments as? List<*>)?.mapNotNull { (it as? Number)?.toLong() }
                        ?: emptyList())
                )
                else -> result.notImplemented()
            }
        }
    }

    /** Listens for the two things that end a hearing, while one is going on. */
    private fun holdAudio() {
        if (noisy == null) {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                        audioChannel?.invokeMethod("interrupted", "noisy")
                    }
                }
            }
            val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
            noisy = receiver
        }
        if (focusRequest == null && Build.VERSION.SDK_INT >= 26) {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            am.requestAudioFocus(request)
            focusRequest = request
        }
    }

    private fun releaseAudio() {
        noisy?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        noisy = null
        if (Build.VERSION.SDK_INT >= 26) {
            focusRequest?.let {
                (getSystemService(Context.AUDIO_SERVICE) as AudioManager).abandonAudioFocusRequest(it)
            }
        }
        focusRequest = null
    }

    /**
     * Vibrates for [pattern]: on, off, on, … in milliseconds, as a web page's
     * `navigator.vibrate` takes it. Played as media, so it follows the media
     * vibration setting rather than the touch-feedback one.
     */
    private fun vibrate(pattern: List<Long>): Boolean {
        if (pattern.isEmpty()) return false
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= 31) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return false
        if (Build.VERSION.SDK_INT < 26) {
            @Suppress("DEPRECATION")
            vibrator.vibrate(longArrayOf(0L) + pattern.toLongArray(), -1)
            return true
        }
        val effect = if (pattern.size == 1) {
            VibrationEffect.createOneShot(pattern[0], VibrationEffect.DEFAULT_AMPLITUDE)
        } else {
            VibrationEffect.createWaveform(longArrayOf(0L) + pattern.toLongArray(), -1)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            vibrator.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA))
        } else {
            vibrator.vibrate(effect)
        }
        return true
    }

    override fun onDestroy() {
        releaseAudio()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent) ?: return
        pendingText = text
        // The app is already running and listening, so hand it over at once.
        channel?.invokeMethod("sharedText", text)
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        return text.ifBlank { null }
    }

    companion object {
        private const val CHANNEL = "kotolang/share"
        private const val AUDIO_CHANNEL = "kotolang/audio"
        private const val FEEL_CHANNEL = "kotolang/feel"
    }
}
