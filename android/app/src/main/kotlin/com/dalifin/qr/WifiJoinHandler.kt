package com.dalifin.qr

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** User-mediated saved networks, never app-local routing or silent joins. */
class WifiJoinHandler(private val activity: Activity) {
    companion object { private const val REQUEST_CODE = 0xDA11 }
    private var pending: MethodChannel.Result? = null

    /** Never send credentials to a third-party handler or an intent chooser. */
    private fun systemSettingsIntent(action: String): Intent? {
        val intent = Intent(action)
        val manager = activity.packageManager
        val matches = manager.queryIntentActivities(
            intent, PackageManager.MATCH_SYSTEM_ONLY or PackageManager.MATCH_DEFAULT_ONLY,
        ).filter {
            it.activityInfo.exported && it.activityInfo.applicationInfo.flags and
                (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        }
        val preferred = intent.resolveActivity(manager)
        val selected = matches.firstOrNull {
            it.activityInfo.packageName == preferred?.packageName &&
                it.activityInfo.name == preferred?.className
        } ?: matches.singleOrNull()
            ?: matches.firstOrNull { it.activityInfo.packageName == "com.android.settings" }
            ?: return null
        return intent.setClassName(selected.activityInfo.packageName, selected.activityInfo.name)
    }

    fun openSettings(): Boolean = runCatching {
        val intent = systemSettingsIntent(Settings.ACTION_WIFI_SETTINGS) ?: return false
        activity.startActivity(intent)
        true
    }.getOrDefault(false)

    fun capabilities(): Map<String, Any> {
        val hardware = activity.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI)
        val settings = hardware && systemSettingsIntent(Settings.ACTION_WIFI_SETTINGS) != null
        val types = mutableListOf<String>()
        if (hardware && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            systemSettingsIntent(Settings.ACTION_WIFI_ADD_NETWORKS) != null) {
            types.addAll(listOf("open", "wpa2"))
            val manager = activity.applicationContext.getSystemService(Activity.WIFI_SERVICE) as? WifiManager
            if (runCatching { manager?.isWpa3SaeSupported == true }.getOrDefault(false)) types.add("wpa3")
        }
        return mapOf("securityTypes" to types, "canOpenSettings" to settings)
    }

    fun join(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) { result.success("busy"); return }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) { result.success("unsupported"); return }
        try {
            val ssid = call.argument<String>("ssid") ?: ""
            val password = call.argument<String>("password") ?: ""
            val security = call.argument<String>("security") ?: ""
            val hidden = call.argument<Boolean>("hidden") ?: false
            require(ssid.isNotEmpty() && ssid.toByteArray(Charsets.UTF_8).size <= 32)
            require(ssid.none { it.code < 32 || it.code == 127 })
            require(String(ssid.toByteArray(Charsets.UTF_8), Charsets.UTF_8) == ssid)
            val types = capabilities()["securityTypes"] as? List<*> ?: emptyList<String>()
            if (security !in types) { result.success("unsupported"); return }
            val builder = WifiNetworkSuggestion.Builder().setSsid(ssid).setIsHiddenSsid(hidden)
            when (security) {
                "open" -> require(password.isEmpty())
                "wpa2", "wpa3" -> {
                    val minimum = if (security == "wpa3") 1 else 8
                    require(password.length in minimum..63 && password.all { it.code in 32..126 })
                    if (security == "wpa3") builder.setWpa3Passphrase(password) else builder.setWpa2Passphrase(password)
                }
                else -> { result.success("unsupported"); return }
            }
            val intent = systemSettingsIntent(Settings.ACTION_WIFI_ADD_NETWORKS)
            if (intent == null) { result.success("unsupported"); return }
            intent.putParcelableArrayListExtra(
                Settings.EXTRA_WIFI_NETWORK_LIST, arrayListOf(builder.build()))
            pending = result
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (_: Exception) {
            pending = null
            result.success("failed")
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val status = if (resultCode != Activity.RESULT_OK) "cancelled"
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val codes = data?.getIntegerArrayListExtra(Settings.EXTRA_WIFI_NETWORK_RESULT_LIST)
            if (codes?.size != 1) "failed" else when (codes[0]) {
                Settings.ADD_WIFI_RESULT_SUCCESS -> "saved"
                Settings.ADD_WIFI_RESULT_ALREADY_EXISTS -> "alreadySaved"
                else -> "failed"
            }
        } else "unsupported"
        result.success(status)
        return true
    }

    fun dispose() {
        pending?.success("cancelled")
        pending = null
    }
}
