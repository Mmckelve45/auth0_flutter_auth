import Cocoa
import FlutterMacOS
import AuthenticationServices

public class Auth0FlutterAuthPlugin: NSObject, FlutterPlugin {
    private var currentSession: ASWebAuthenticationSession?
    private var contextProvider: MacContextProvider?
    private let browserChannel: FlutterMethodChannel
    private let dpopChannel: FlutterMethodChannel
    private let passkeysChannel: FlutterMethodChannel

    init(browserChannel: FlutterMethodChannel, dpopChannel: FlutterMethodChannel, passkeysChannel: FlutterMethodChannel) {
        self.browserChannel = browserChannel
        self.dpopChannel = dpopChannel
        self.passkeysChannel = passkeysChannel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let browserChannel = FlutterMethodChannel(
            name: "com.auth0.flutter_auth/browser",
            binaryMessenger: registrar.messenger
        )
        let dpopChannel = FlutterMethodChannel(
            name: "com.auth0.flutter_auth/dpop",
            binaryMessenger: registrar.messenger
        )
        let passkeysChannel = FlutterMethodChannel(
            name: "com.auth0.flutter_auth/passkeys",
            binaryMessenger: registrar.messenger
        )
        let instance = Auth0FlutterAuthPlugin(
            browserChannel: browserChannel,
            dpopChannel: dpopChannel,
            passkeysChannel: passkeysChannel
        )
        browserChannel.setMethodCallHandler(instance.handleBrowser)
        dpopChannel.setMethodCallHandler(instance.handleDPoP)
        passkeysChannel.setMethodCallHandler(instance.handlePasskeys)
    }

    private func handleBrowser(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "launchAuth":
            guard let args = call.arguments as? [String: Any],
                  let urlString = args["url"] as? String,
                  let callbackScheme = args["callbackScheme"] as? String,
                  let url = URL(string: urlString) else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing url or callbackScheme", details: nil))
                return
            }
            let preferEphemeral = args["preferEphemeral"] as? Bool ?? false
            launchAuth(url: url, callbackScheme: callbackScheme, preferEphemeral: preferEphemeral, result: result)

        case "cancel":
            currentSession?.cancel()
            currentSession = nil
            contextProvider = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func launchAuth(url: URL, callbackScheme: String, preferEphemeral: Bool, result: @escaping FlutterResult) {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
            self?.currentSession = nil
            self?.contextProvider = nil

            if let error = error {
                let nsError = error as NSError
                if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                   nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    result(FlutterError(code: "USER_CANCELLED", message: "User cancelled", details: nil))
                } else {
                    result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: "\(nsError.domain) code=\(nsError.code)"))
                }
                return
            }

            guard let callbackURL = callbackURL else {
                result(FlutterError(code: "NO_CALLBACK", message: "No callback URL received", details: nil))
                return
            }

            result(callbackURL.absoluteString)
        }

        session.prefersEphemeralWebBrowserSession = preferEphemeral

        // IMPORTANT: presentationContextProvider is a weak reference on ASWebAuthenticationSession,
        // so we must store the provider as a property to prevent it from being deallocated.
        guard let window = NSApplication.shared.windows.first else {
            result(FlutterError(code: "NO_WINDOW", message: "No window available for presentation context", details: nil))
            return
        }

        let provider = MacContextProvider(anchor: window)
        self.contextProvider = provider
        session.presentationContextProvider = provider

        currentSession = session

        DispatchQueue.main.async { [weak self] in
            if !session.start() {
                self?.currentSession = nil
                self?.contextProvider = nil
                result(FlutterError(code: "LAUNCH_FAILED", message: "Failed to start auth session", details: nil))
            }
        }
    }

    private func handleDPoP(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Auth0DPoPHandler.shared.handle(call, result: result)
    }

    private func handlePasskeys(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(macOS 13.0, *) {
            Auth0PasskeysHandler.shared.handle(call, result: result)
        } else {
            result(FlutterError(code: "NOT_AVAILABLE", message: "Passkeys require macOS 13.0+", details: nil))
        }
    }
}

private class MacContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return anchor
    }
}
