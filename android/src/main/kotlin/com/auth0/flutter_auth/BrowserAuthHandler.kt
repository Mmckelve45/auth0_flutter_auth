package com.auth0.flutter_auth

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BrowserAuthHandler : MethodChannel.MethodCallHandler {
    private var activity: Activity? = null
    private var pendingResult: MethodChannel.Result? = null

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "launchAuth" -> {
                val url = call.argument<String>("url")
                val callbackScheme = call.argument<String>("callbackScheme")
                if (url == null || callbackScheme == null) {
                    result.error("INVALID_ARGS", "Missing url or callbackScheme", null)
                    return
                }
                launchAuth(url, callbackScheme, result)
            }
            "cancel" -> {
                pendingResult?.error("USER_CANCELLED", "User cancelled", null)
                pendingResult = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun launchAuth(url: String, callbackScheme: String, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        pendingResult = result

        try {
            val uri = Uri.parse(url)
            val customTabsIntent = CustomTabsIntent.Builder()
                .setShareState(CustomTabsIntent.SHARE_STATE_OFF)
                .build()

            // Find a browser that supports Custom Tabs
            val browserPackage = findCustomTabsBrowser(currentActivity)
            if (browserPackage != null) {
                customTabsIntent.intent.setPackage(browserPackage)
            }

            customTabsIntent.launchUrl(currentActivity, uri)
        } catch (e: Exception) {
            pendingResult = null
            result.error("LAUNCH_FAILED", "Failed to launch browser: ${e.message}", null)
        }
    }

    fun handleCallback(callbackUrl: String) {
        val result = pendingResult
        pendingResult = null
        result?.success(callbackUrl)
    }

    fun handleCancellation() {
        val result = pendingResult
        pendingResult = null
        result?.error("USER_CANCELLED", "User cancelled", null)
    }

    private fun findCustomTabsBrowser(activity: Activity): String? {
        val browsers = listOf(
            "com.android.chrome",
            "com.chrome.beta",
            "com.chrome.dev",
            "com.chrome.canary",
            "com.microsoft.emmx",
            "org.mozilla.firefox",
            "com.opera.browser",
            "com.brave.browser",
            "com.samsung.android.app.sbrowser",
        )

        val pm = activity.packageManager
        for (browser in browsers) {
            try {
                pm.getPackageInfo(browser, 0)
                return browser
            } catch (_: PackageManager.NameNotFoundException) {
                // Continue
            }
        }

        // Fallback: find any browser with Custom Tabs support
        val browseIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://auth0.com"))
        val resolvedActivities = pm.queryIntentActivities(browseIntent, PackageManager.MATCH_DEFAULT_ONLY)
        return resolvedActivities.firstOrNull()?.activityInfo?.packageName
    }

    companion object {
        // Singleton reference for CallbackActivity to find
        @Volatile
        var instance: BrowserAuthHandler? = null
    }

    init {
        instance = this
    }
}
