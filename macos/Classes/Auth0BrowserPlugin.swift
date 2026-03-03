import Cocoa
import FlutterMacOS
import AuthenticationServices

public class Auth0FlutterAuthPlugin: NSObject, FlutterPlugin {
    private var currentSession: ASWebAuthenticationSession?
    private let browserChannel: FlutterMethodChannel
    private let dpopChannel: FlutterMethodChannel

    init(browserChannel: FlutterMethodChannel, dpopChannel: FlutterMethodChannel) {
        self.browserChannel = browserChannel
        self.dpopChannel = dpopChannel
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
        let instance = Auth0FlutterAuthPlugin(
            browserChannel: browserChannel,
            dpopChannel: dpopChannel
        )
        browserChannel.setMethodCallHandler(instance.handleBrowser)
        dpopChannel.setMethodCallHandler(instance.handleDPoP)
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
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func launchAuth(url: URL, callbackScheme: String, preferEphemeral: Bool, result: @escaping FlutterResult) {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
            self.currentSession = nil

            if let error = error {
                let nsError = error as NSError
                if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                   nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    result(FlutterError(code: "USER_CANCELLED", message: "User cancelled", details: nil))
                } else {
                    result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
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

        if let window = NSApplication.shared.windows.first {
            session.presentationContextProvider = MacContextProvider(anchor: window)
        }

        currentSession = session

        if !session.start() {
            currentSession = nil
            result(FlutterError(code: "LAUNCH_FAILED", message: "Failed to start auth session", details: nil))
        }
    }

    private func handleDPoP(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Auth0DPoPHandler.shared.handle(call, result: result)
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
