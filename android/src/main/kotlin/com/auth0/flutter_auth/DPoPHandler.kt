package com.auth0.flutter_auth

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.security.*
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.util.UUID

class DPoPHandler : MethodChannel.MethodCallHandler {

    companion object {
        private const val KEY_ALIAS = "com.auth0.flutter_auth.dpop.ec"
        private const val KEYSTORE_TYPE = "AndroidKeyStore"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "generateKeyPair" -> generateKeyPair(result)
            "signProof" -> {
                val url = call.argument<String>("url")
                val method = call.argument<String>("method")
                val accessToken = call.argument<String>("accessToken")
                val nonce = call.argument<String>("nonce")
                if (url == null || method == null) {
                    result.error("INVALID_ARGS", "Missing url or method", null)
                    return
                }
                signProof(url, method, accessToken, nonce, result)
            }
            "clearKeyPair" -> clearKeyPair(result)
            "hasKeyPair" -> result.success(hasKeyPair())
            else -> result.notImplemented()
        }
    }

    private fun generateKeyPair(result: MethodChannel.Result) {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE_TYPE).apply { load(null) }
            // Delete existing key
            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.deleteEntry(KEY_ALIAS)
            }

            val paramBuilder = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                paramBuilder.setIsStrongBoxBacked(true)
            }

            val keyPairGenerator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC, KEYSTORE_TYPE
            )

            try {
                keyPairGenerator.initialize(paramBuilder.build())
                keyPairGenerator.generateKeyPair()
            } catch (e: Exception) {
                // Fallback without StrongBox
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    paramBuilder.setIsStrongBoxBacked(false)
                    keyPairGenerator.initialize(paramBuilder.build())
                    keyPairGenerator.generateKeyPair()
                } else {
                    throw e
                }
            }

            result.success(null)
        } catch (e: Exception) {
            result.error("KEY_GEN_FAILED", "Failed to generate key pair: ${e.message}", null)
        }
    }

    private fun signProof(
        url: String,
        method: String,
        accessToken: String?,
        nonce: String?,
        result: MethodChannel.Result
    ) {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE_TYPE).apply { load(null) }
            val privateKey = keyStore.getKey(KEY_ALIAS, null) as? PrivateKey
                ?: run {
                    result.error("NO_KEY", "No key pair available", null)
                    return
                }
            val publicKey = keyStore.getCertificate(KEY_ALIAS)?.publicKey as? ECPublicKey
                ?: run {
                    result.error("NO_PUBLIC_KEY", "Cannot extract public key", null)
                    return
                }

            // Extract x, y from EC public key
            val point = publicKey.w
            val x = point.affineX.toByteArray().let { padOrTrim(it, 32) }
            val y = point.affineY.toByteArray().let { padOrTrim(it, 32) }

            val jwk = JSONObject().apply {
                put("kty", "EC")
                put("crv", "P-256")
                put("x", base64UrlEncode(x))
                put("y", base64UrlEncode(y))
            }

            val header = JSONObject().apply {
                put("typ", "dpop+jwt")
                put("alg", "ES256")
                put("jwk", jwk)
            }

            val payload = JSONObject().apply {
                put("jti", UUID.randomUUID().toString())
                put("htm", method.uppercase())
                put("htu", url)
                put("iat", System.currentTimeMillis() / 1000)
                nonce?.let { put("nonce", it) }
                accessToken?.let {
                    val md = MessageDigest.getInstance("SHA-256")
                    val hash = md.digest(it.toByteArray(Charsets.UTF_8))
                    put("ath", base64UrlEncode(hash))
                }
            }

            val headerB64 = base64UrlEncode(header.toString().toByteArray(Charsets.UTF_8))
            val payloadB64 = base64UrlEncode(payload.toString().toByteArray(Charsets.UTF_8))
            val signingInput = "$headerB64.$payloadB64"

            val signature = Signature.getInstance("SHA256withECDSA").apply {
                initSign(privateKey)
                update(signingInput.toByteArray(Charsets.UTF_8))
            }.sign()

            // Convert DER to raw R||S
            val rawSignature = derToRaw(signature)
            val signatureB64 = base64UrlEncode(rawSignature)

            result.success("$signingInput.$signatureB64")
        } catch (e: Exception) {
            result.error("SIGN_FAILED", "Failed to sign proof: ${e.message}", null)
        }
    }

    private fun clearKeyPair(result: MethodChannel.Result) {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE_TYPE).apply { load(null) }
            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.deleteEntry(KEY_ALIAS)
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("CLEAR_FAILED", "Failed to clear key pair: ${e.message}", null)
        }
    }

    private fun hasKeyPair(): Boolean {
        return try {
            val keyStore = KeyStore.getInstance(KEYSTORE_TYPE).apply { load(null) }
            keyStore.containsAlias(KEY_ALIAS)
        } catch (_: Exception) {
            false
        }
    }

    private fun base64UrlEncode(data: ByteArray): String {
        return Base64.encodeToString(data, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun padOrTrim(bytes: ByteArray, length: Int): ByteArray {
        return when {
            bytes.size == length -> bytes
            bytes.size > length -> bytes.copyOfRange(bytes.size - length, bytes.size)
            else -> ByteArray(length - bytes.size) + bytes
        }
    }

    private fun derToRaw(der: ByteArray): ByteArray {
        if (der.size < 8 || der[0] != 0x30.toByte()) return der

        var offset = 2
        if (der[offset] != 0x02.toByte()) return der
        offset++
        val rLen = der[offset].toInt() and 0xFF
        offset++
        var r = der.copyOfRange(offset, offset + rLen)
        offset += rLen

        if (der[offset] != 0x02.toByte()) return der
        offset++
        val sLen = der[offset].toInt() and 0xFF
        offset++
        var s = der.copyOfRange(offset, offset + sLen)

        // Remove leading zero padding
        if (r.size == 33 && r[0] == 0x00.toByte()) r = r.copyOfRange(1, 33)
        if (s.size == 33 && s[0] == 0x00.toByte()) s = s.copyOfRange(1, 33)

        val raw = ByteArray(64)
        System.arraycopy(r, 0, raw, 32 - r.size, r.size)
        System.arraycopy(s, 0, raw, 64 - s.size, s.size)
        return raw
    }
}
