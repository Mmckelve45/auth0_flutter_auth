import Foundation
import Flutter
import AuthenticationServices

@available(iOS 16.0, *)
class Auth0PasskeysHandler: NSObject {
    static let shared = Auth0PasskeysHandler()

    private var pendingResult: FlutterResult?
    private var presentationAnchor: ASPresentationAnchor?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "register":
            guard let args = call.arguments as? [String: Any],
                  let optionsJson = args["optionsJson"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing optionsJson", details: nil))
                return
            }
            register(optionsJson: optionsJson, result: result)
        case "authenticate":
            guard let args = call.arguments as? [String: Any],
                  let optionsJson = args["optionsJson"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing optionsJson", details: nil))
                return
            }
            authenticate(optionsJson: optionsJson, result: result)
        case "isAvailable":
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Registration

    private func register(optionsJson: String, result: @escaping FlutterResult) {
        guard let data = optionsJson.data(using: .utf8),
              let options = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rp = options["rp"] as? [String: Any],
              let rpId = rp["id"] as? String,
              let user = options["user"] as? [String: Any],
              let userName = user["name"] as? String,
              let userIdString = user["id"] as? String,
              let userId = userIdString.data(using: .utf8),
              let challengeString = options["challenge"] as? String,
              let challenge = Data(base64URLEncoded: challengeString) else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid registration options JSON", details: nil))
            return
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: userName,
            userID: userId
        )

        presentAndAuthorize(requests: [request], result: result)
    }

    // MARK: - Authentication

    private func authenticate(optionsJson: String, result: @escaping FlutterResult) {
        guard let data = optionsJson.data(using: .utf8),
              let options = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let challengeString = options["challenge"] as? String,
              let challenge = Data(base64URLEncoded: challengeString) else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid authentication options JSON", details: nil))
            return
        }

        let rpId = options["rpId"] as? String ?? ""
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)

        presentAndAuthorize(requests: [request], result: result)
    }

    // MARK: - Shared

    private func presentAndAuthorize(requests: [ASAuthorizationRequest], result: @escaping FlutterResult) {
        guard let window = findKeyWindow() else {
            result(FlutterError(code: "NO_WINDOW", message: "No key window available", details: nil))
            return
        }

        self.pendingResult = result
        self.presentationAnchor = window

        let controller = ASAuthorizationController(authorizationRequests: requests)
        controller.delegate = self
        controller.presentationContextProvider = self

        DispatchQueue.main.async {
            controller.performRequests()
        }
    }

    private func findKeyWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if #available(iOS 15.0, *) {
                if let keyWindow = windowScene.keyWindow {
                    return keyWindow
                }
            }
            for window in windowScene.windows where window.isKeyWindow {
                return window
            }
            if let window = windowScene.windows.first {
                return window
            }
        }
        return nil
    }

    private func complete(with result: Any?) {
        let pending = pendingResult
        pendingResult = nil
        presentationAnchor = nil
        pending?(result)
    }
}

@available(iOS 16.0, *)
extension Auth0PasskeysHandler: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        if let registration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            let response: [String: Any] = [
                "id": registration.credentialID.base64URLEncoded(),
                "rawId": registration.credentialID.base64URLEncoded(),
                "type": "public-key",
                "response": [
                    "attestationObject": (registration.rawAttestationObject ?? Data()).base64URLEncoded(),
                    "clientDataJSON": registration.rawClientDataJSON.base64URLEncoded(),
                ],
                "authenticatorAttachment": "platform",
            ]
            if let json = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: json, encoding: .utf8) {
                complete(with: jsonString)
            } else {
                complete(with: FlutterError(code: "REGISTRATION_FAILED", message: "Failed to serialize response", details: nil))
            }

        } else if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            let response: [String: Any] = [
                "id": assertion.credentialID.base64URLEncoded(),
                "rawId": assertion.credentialID.base64URLEncoded(),
                "type": "public-key",
                "response": [
                    "authenticatorData": assertion.rawAuthenticatorData.base64URLEncoded(),
                    "clientDataJSON": assertion.rawClientDataJSON.base64URLEncoded(),
                    "signature": assertion.signature.base64URLEncoded(),
                    "userHandle": (assertion.userID ?? Data()).base64URLEncoded(),
                ],
                "authenticatorAttachment": "platform",
            ]
            if let json = try? JSONSerialization.data(withJSONObject: response),
               let jsonString = String(data: json, encoding: .utf8) {
                complete(with: jsonString)
            } else {
                complete(with: FlutterError(code: "ASSERTION_FAILED", message: "Failed to serialize response", details: nil))
            }
        } else {
            complete(with: FlutterError(code: "PLATFORM_ERROR", message: "Unknown credential type", details: nil))
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            complete(with: FlutterError(code: "CANCELLED", message: "User cancelled", details: nil))
        } else {
            complete(with: FlutterError(code: "PLATFORM_ERROR", message: error.localizedDescription, details: "\(nsError.domain) code=\(nsError.code)"))
        }
    }
}

@available(iOS 16.0, *)
extension Auth0PasskeysHandler: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return presentationAnchor ?? UIWindow()
    }
}

// MARK: - Base64URL decoding helper

private extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }
}
