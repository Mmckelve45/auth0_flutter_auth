import Foundation
import FlutterMacOS
import Security
import CommonCrypto

class Auth0DPoPHandler {
    static let shared = Auth0DPoPHandler()

    private let keyTag = "com.auth0.flutter_auth.dpop.ec"
    private var keyPair: SecKey?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "generateKeyPair":
            generateKeyPair(result: result)
        case "signProof":
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String,
                  let method = args["method"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing url or method", details: nil))
                return
            }
            let accessToken = args["accessToken"] as? String
            let nonce = args["nonce"] as? String
            signProof(url: url, method: method, accessToken: accessToken, nonce: nonce, result: result)
        case "clearKeyPair":
            clearKeyPair(result: result)
        case "hasKeyPair":
            result(keyPair != nil || loadKey() != nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func generateKeyPair(result: @escaping FlutterResult) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrApplicationTag as String: keyTag,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: keyTag,
            ],
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            result(FlutterError(code: "KEY_GEN_FAILED", message: "Failed to generate key pair", details: nil))
            return
        }

        keyPair = privateKey
        result(nil)
    }

    private func signProof(url: String, method: String, accessToken: String?, nonce: String?, result: @escaping FlutterResult) {
        guard let privateKey = keyPair ?? loadKey() else {
            result(FlutterError(code: "NO_KEY", message: "No key pair available", details: nil))
            return
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            result(FlutterError(code: "NO_PUBLIC_KEY", message: "Cannot extract public key", details: nil))
            return
        }

        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            result(FlutterError(code: "KEY_EXPORT_FAILED", message: "Cannot export public key", details: nil))
            return
        }

        let x = publicKeyData[1...32]
        let y = publicKeyData[33...64]

        let jwk: [String: String] = [
            "kty": "EC",
            "crv": "P-256",
            "x": x.base64URLEncoded(),
            "y": y.base64URLEncoded(),
        ]

        let header: [String: Any] = [
            "typ": "dpop+jwt",
            "alg": "ES256",
            "jwk": jwk,
        ]

        var payload: [String: Any] = [
            "jti": UUID().uuidString,
            "htm": method.uppercased(),
            "htu": url,
            "iat": Int(Date().timeIntervalSince1970),
        ]

        if let nonce = nonce {
            payload["nonce"] = nonce
        }

        if let accessToken = accessToken {
            if let tokenData = accessToken.data(using: .utf8) {
                var hash = [UInt8](repeating: 0, count: 32)
                tokenData.withUnsafeBytes { bytes in
                    _ = CC_SHA256(bytes.baseAddress, CC_LONG(tokenData.count), &hash)
                }
                payload["ath"] = Data(hash).base64URLEncoded()
            }
        }

        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize JWT", details: nil))
            return
        }

        let headerB64 = headerData.base64URLEncoded()
        let payloadB64 = payloadData.base64URLEncoded()
        let signingInput = "\(headerB64).\(payloadB64)"

        guard let signingData = signingInput.data(using: .utf8) else {
            result(FlutterError(code: "ENCODING_ERROR", message: "Failed to encode signing input", details: nil))
            return
        }

        var signError: Unmanaged<CFError>?
        guard let signatureData = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            signingData as CFData,
            &signError
        ) as Data? else {
            result(FlutterError(code: "SIGN_FAILED", message: "Failed to sign proof", details: nil))
            return
        }

        let rawSignature = derToRaw(signatureData)
        let signatureB64 = rawSignature.base64URLEncoded()

        result("\(signingInput).\(signatureB64)")
    }

    private func clearKeyPair(result: @escaping FlutterResult) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
        ]
        SecItemDelete(query as CFDictionary)
        keyPair = nil
        result(nil)
    }

    private func loadKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            keyPair = (item as! SecKey)
            return keyPair
        }
        return nil
    }

    private func derToRaw(_ der: Data) -> Data {
        var index = 2
        if der[0] != 0x30 { return der }

        guard index < der.count, der[index] == 0x02 else { return der }
        index += 1
        let rLen = Int(der[index])
        index += 1
        var r = der[index..<(index + rLen)]
        index += rLen

        guard index < der.count, der[index] == 0x02 else { return der }
        index += 1
        let sLen = Int(der[index])
        index += 1
        var s = der[index..<(index + sLen)]

        if r.count == 33 && r.first == 0x00 { r = r.dropFirst() }
        if s.count == 33 && s.first == 0x00 { s = s.dropFirst() }

        var raw = Data(count: 64)
        let rOffset = 32 - r.count
        let sOffset = 32 - s.count
        raw.replaceSubrange(rOffset..<(rOffset + r.count), with: r)
        raw.replaceSubrange((32 + sOffset)..<(32 + sOffset + s.count), with: s)

        return raw
    }
}

extension Data {
    func base64URLEncoded() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
