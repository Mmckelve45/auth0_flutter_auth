package com.auth0.flutter_auth

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

class Auth0FlutterAuthPlugin : FlutterPlugin, ActivityAware {
    private var browserChannel: MethodChannel? = null
    private var dpopChannel: MethodChannel? = null
    private var passkeysChannel: MethodChannel? = null
    private val browserHandler = BrowserAuthHandler()
    private val dpopHandler = DPoPHandler()
    private val passkeysHandler = PasskeysHandler()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        browserChannel = MethodChannel(binding.binaryMessenger, "com.auth0.flutter_auth/browser").also {
            it.setMethodCallHandler(browserHandler)
        }
        dpopChannel = MethodChannel(binding.binaryMessenger, "com.auth0.flutter_auth/dpop").also {
            it.setMethodCallHandler(dpopHandler)
        }
        passkeysChannel = MethodChannel(binding.binaryMessenger, "com.auth0.flutter_auth/passkeys").also {
            it.setMethodCallHandler(passkeysHandler)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        browserChannel?.setMethodCallHandler(null)
        dpopChannel?.setMethodCallHandler(null)
        passkeysChannel?.setMethodCallHandler(null)
        browserChannel = null
        dpopChannel = null
        passkeysChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        browserHandler.setActivity(binding.activity)
        passkeysHandler.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        browserHandler.setActivity(null)
        passkeysHandler.setActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        browserHandler.setActivity(binding.activity)
        passkeysHandler.setActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        browserHandler.setActivity(null)
        passkeysHandler.setActivity(null)
    }
}
