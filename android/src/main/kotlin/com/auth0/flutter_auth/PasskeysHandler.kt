package com.auth0.flutter_auth

import android.app.Activity
import android.os.Build
import android.util.Base64
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class PasskeysHandler : MethodChannel.MethodCallHandler {
    private var activity: Activity? = null
    private val scope = CoroutineScope(Dispatchers.Main)

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "register" -> {
                val optionsJson = call.argument<String>("optionsJson")
                if (optionsJson == null) {
                    result.error("INVALID_ARGS", "Missing optionsJson", null)
                    return
                }
                register(optionsJson, result)
            }
            "authenticate" -> {
                val optionsJson = call.argument<String>("optionsJson")
                if (optionsJson == null) {
                    result.error("INVALID_ARGS", "Missing optionsJson", null)
                    return
                }
                authenticate(optionsJson, result)
            }
            "isAvailable" -> {
                result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            }
            else -> result.notImplemented()
        }
    }

    private fun register(optionsJson: String, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        val credentialManager = CredentialManager.create(currentActivity)
        val request = CreatePublicKeyCredentialRequest(requestJson = optionsJson)

        scope.launch {
            try {
                val response = credentialManager.createCredential(
                    context = currentActivity,
                    request = request,
                )
                handleRegistrationResponse(response, result)
            } catch (e: CreateCredentialCancellationException) {
                result.error("CANCELLED", "User cancelled passkey registration", e.message)
            } catch (e: CreateCredentialException) {
                result.error(
                    "REGISTRATION_FAILED",
                    "Passkey registration failed: ${e.type}",
                    e.message
                )
            } catch (e: Exception) {
                result.error("PLATFORM_ERROR", "Unexpected error: ${e.message}", null)
            }
        }
    }

    private fun handleRegistrationResponse(
        response: CreateCredentialResponse,
        result: MethodChannel.Result
    ) {
        if (response is CreatePublicKeyCredentialResponse) {
            result.success(response.registrationResponseJson)
        } else {
            result.error(
                "REGISTRATION_FAILED",
                "Unexpected credential response type",
                null
            )
        }
    }

    private fun authenticate(optionsJson: String, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        val credentialManager = CredentialManager.create(currentActivity)
        val publicKeyOption = GetPublicKeyCredentialOption(requestJson = optionsJson)
        val request = GetCredentialRequest(listOf(publicKeyOption))

        scope.launch {
            try {
                val response = credentialManager.getCredential(
                    context = currentActivity,
                    request = request,
                )
                val credential = response.credential
                if (credential is PublicKeyCredential) {
                    result.success(credential.authenticationResponseJson)
                } else {
                    result.error(
                        "ASSERTION_FAILED",
                        "Unexpected credential type",
                        null
                    )
                }
            } catch (e: GetCredentialCancellationException) {
                result.error("CANCELLED", "User cancelled passkey authentication", e.message)
            } catch (e: NoCredentialException) {
                result.error("NOT_AVAILABLE", "No passkey credentials found", e.message)
            } catch (e: GetCredentialException) {
                result.error(
                    "ASSERTION_FAILED",
                    "Passkey authentication failed: ${e.type}",
                    e.message
                )
            } catch (e: Exception) {
                result.error("PLATFORM_ERROR", "Unexpected error: ${e.message}", null)
            }
        }
    }
}
