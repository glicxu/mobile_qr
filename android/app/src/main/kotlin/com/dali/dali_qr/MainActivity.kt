package com.dali.dali_qr

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dali_qr/clipboard",
        ).setMethodCallHandler { call, result ->
            if (call.method != "copyPng") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val bytes = call.argument<ByteArray>("bytes")
            val payload = call.argument<String>("payload")
            if (bytes == null || payload == null) {
                result.error("invalid_arguments", "PNG bytes and payload are required.", null)
                return@setMethodCallHandler
            }

            try {
                val image = File(cacheDir, "dali_qr_clipboard.png")
                image.writeBytes(bytes)
                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    image,
                )
                val clip = ClipData.newUri(contentResolver, "QR code", uri).apply {
                    addItem(ClipData.Item(payload))
                }
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(clip)
                result.success(null)
            } catch (error: Exception) {
                result.error("copy_failed", error.message, null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dali_qr/routing",
        ).setMethodCallHandler { call, result ->
            try {
                val intent = when (call.method) {
                    "configureWifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
                    "addContact" -> Intent(
                        Intent.ACTION_INSERT,
                        ContactsContract.Contacts.CONTENT_URI,
                    ).apply {
                        putExtra(
                            ContactsContract.Intents.Insert.NAME,
                            call.argument<String>("name"),
                        )
                        putExtra(
                            ContactsContract.Intents.Insert.PHONE,
                            call.argument<String>("phone"),
                        )
                        putExtra(
                            ContactsContract.Intents.Insert.EMAIL,
                            call.argument<String>("email"),
                        )
                    }
                    "addCalendarEvent" -> Intent(
                        Intent.ACTION_INSERT,
                        CalendarContract.Events.CONTENT_URI,
                    ).apply {
                        putExtra(
                            CalendarContract.Events.TITLE,
                            call.argument<String>("title"),
                        )
                        putExtra(
                            CalendarContract.Events.EVENT_LOCATION,
                            call.argument<String>("location"),
                        )
                        putExtra(
                            CalendarContract.Events.DESCRIPTION,
                            call.argument<String>("description"),
                        )
                        call.argument<Number>("startMillis")?.let {
                            putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, it.toLong())
                        }
                        call.argument<Number>("endMillis")?.let {
                            putExtra(CalendarContract.EXTRA_EVENT_END_TIME, it.toLong())
                        }
                    }
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                startActivity(intent)
                result.success(true)
            } catch (error: Exception) {
                result.error("route_failed", error.message, null)
            }
        }
    }
}
