package com.auth0.flutter_auth

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

class Auth0FlutterAuthPlugin : FlutterPlugin, ActivityAware {
    private var browserChannel: MethodChannel? = null
    private var dpopChannel: MethodChannel? = null
    private val browserHandler = BrowserAuthHandler()
    private val dpopHandler = DPoPHandler()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        browserChannel = MethodChannel(binding.binaryMessenger, "com.auth0.flutter_auth/browser").also {
            it.setMethodCallHandler(browserHandler)
        }
        dpopChannel = MethodChannel(binding.binaryMessenger, "com.auth0.flutter_auth/dpop").also {
            it.setMethodCallHandler(dpopHandler)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        browserChannel?.setMethodCallHandler(null)
        dpopChannel?.setMethodCallHandler(null)
        browserChannel = null
        dpopChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        browserHandler.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        browserHandler.setActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        browserHandler.setActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        browserHandler.setActivity(null)
    }
}
