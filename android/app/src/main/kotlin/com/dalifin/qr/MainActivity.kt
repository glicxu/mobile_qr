package com.dalifin.qr

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.CalendarContract
import android.provider.ContactsContract
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private companion object {
        const val MAX_SHARED_IMAGE_BYTES = 25L * 1024L * 1024L
        const val SHARED_CODE_PREFIX = "dali_shared_code_"
        const val LEGACY_SHARED_QR_PREFIX = "dali_shared_qr_"
    }

    private var inboundShareChannel: MethodChannel? = null
    private var pendingSharedImagePath: String? = null
    private var pendingSharedImageError: Map<String, String>? = null
    private lateinit var wifiJoinHandler: WifiJoinHandler

    override fun getDartEntrypointArgs(): List<String> {
        val arguments = super.getDartEntrypointArgs().orEmpty()
        return if (intent?.action == Intent.ACTION_SEND) {
            arguments + "--dali-shared-image"
        } else arguments
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        wifiJoinHandler = WifiJoinHandler(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dali_qr/local_storage")
            .setMethodCallHandler { call, result ->
                if (call.method != "batchDatabasePath" && call.method != "paymentsDatabasePath") {
                    result.notImplemented()
                } else {
                    try {
                        val payments = call.method == "paymentsDatabasePath"
                        val directory = File(noBackupFilesDir, if (payments) "dali_payments" else "dali_batch")
                        check(directory.exists() || directory.mkdirs())
                        result.success(File(directory, if (payments) "payments.sqlite" else "batch.sqlite").absolutePath)
                    } catch (_: Exception) {
                        result.error("storage_unavailable", "Protected local storage is unavailable.", null)
                    }
                }
            }
        inboundShareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dali_qr/inbound_share",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "takeInitialImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(pendingSharedImagePath ?: pendingSharedImageError)
                pendingSharedImagePath = null
                pendingSharedImageError = null
            }
        }
        cleanupStaleSharedImages()
        receiveSharedImage(intent, notifyFlutter = false)

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
            if (call.method == "wifiJoinCapabilities") {
                result.success(wifiJoinHandler.capabilities())
                return@setMethodCallHandler
            }
            if (call.method == "joinWifi") {
                wifiJoinHandler.join(call, result)
                return@setMethodCallHandler
            }
            if (call.method == "configureWifi") {
                result.success(wifiJoinHandler.openSettings())
                return@setMethodCallHandler
            }
            try {
                val intent = when (call.method) {
                    "authenticatePasskey" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        require(Regex("FIDO:/[0-9]+").matches(uri))
                        Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                    }
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveSharedImage(intent, notifyFlutter = true)
    }

    @Deprecated("Activity result bridge for the system Wi-Fi approval flow")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (::wifiJoinHandler.isInitialized && wifiJoinHandler.onActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        if (::wifiJoinHandler.isInitialized) wifiJoinHandler.dispose()
        super.onDestroy()
    }

    private fun receiveSharedImage(intent: Intent?, notifyFlutter: Boolean) {
        if (intent?.action != Intent.ACTION_SEND ||
            intent.type?.startsWith("image/") != true ||
            intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        ) {
            return
        }

        var sharedImage: File? = null
        pendingSharedImageError = null
        try {
            val uri = requireNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            pendingSharedImagePath?.let { File(it).delete() }
            val destination = File.createTempFile(SHARED_CODE_PREFIX, ".image", cacheDir)
            sharedImage = destination
            contentResolver.openInputStream(uri).use { input ->
                requireNotNull(input) { "The shared image could not be opened." }
                destination.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        require(total <= MAX_SHARED_IMAGE_BYTES) {
                            "The shared image is larger than 25 MB."
                        }
                        output.write(buffer, 0, count)
                    }
                }
            }
            pendingSharedImagePath = destination.absolutePath
            if (notifyFlutter) notifyFlutterOfSharedImage(destination.absolutePath)
        } catch (_: Exception) {
            sharedImage?.delete()
            pendingSharedImagePath = null
            val error = mapOf(
                "id" to UUID.randomUUID().toString(),
                "error" to "The shared image could not be opened. Choose an accessible image smaller than 25 MB.",
            )
            pendingSharedImageError = error
            if (notifyFlutter) notifyFlutterOfShare(error)
        }
    }

    private fun cleanupStaleSharedImages() {
        cacheDir.listFiles()?.forEach { file ->
            if (file.name.startsWith(SHARED_CODE_PREFIX) ||
                file.name.startsWith(LEGACY_SHARED_QR_PREFIX)
            ) {
                file.delete()
            }
        }
    }

    private fun notifyFlutterOfSharedImage(path: String) {
        notifyFlutterOfShare(path)
    }

    private fun notifyFlutterOfShare(value: Any) {
        inboundShareChannel?.invokeMethod(
            "sharedImage",
            value,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (pendingSharedImagePath == value) pendingSharedImagePath = null
                    if (pendingSharedImageError == value) pendingSharedImageError = null
                }

                override fun error(code: String, message: String?, details: Any?) = Unit

                override fun notImplemented() = Unit
            },
        )
    }
}
