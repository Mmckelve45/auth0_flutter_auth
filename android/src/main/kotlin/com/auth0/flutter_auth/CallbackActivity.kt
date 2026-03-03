package com.auth0.flutter_auth

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Activity that intercepts the OAuth redirect URI.
 *
 * Declare in AndroidManifest.xml with an intent-filter matching your callback URL scheme:
 * <activity android:name="com.auth0.flutter_auth.CallbackActivity"
 *           android:exported="true"
 *           android:launchMode="singleTask">
 *     <intent-filter>
 *         <action android:name="android.intent.action.VIEW" />
 *         <category android:name="android.intent.category.DEFAULT" />
 *         <category android:name="android.intent.category.BROWSABLE" />
 *         <data android:scheme="${applicationId}"
 *               android:host="callback" />
 *     </intent-filter>
 * </activity>
 */
class CallbackActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.let { handleIntent(it) }
    }

    private fun handleIntent(intent: Intent) {
        val data = intent.data
        if (data != null) {
            // Check for error parameter
            val error = data.getQueryParameter("error")
            if (error != null) {
                if (error == "access_denied" || error == "login_required") {
                    BrowserAuthHandler.instance?.handleCancellation()
                } else {
                    BrowserAuthHandler.instance?.handleCallback(data.toString())
                }
            } else {
                BrowserAuthHandler.instance?.handleCallback(data.toString())
            }
        } else {
            BrowserAuthHandler.instance?.handleCancellation()
        }

        // Return to the app
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(launchIntent)
        }

        finish()
    }
}
