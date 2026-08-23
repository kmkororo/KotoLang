package com.kmkor.kotolang

import android.content.Intent
import android.os.Bundle
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
 */
class MainActivity : FlutterActivity() {
    private var pendingText: String? = null
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingText = extractSharedText(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
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
    }
}
