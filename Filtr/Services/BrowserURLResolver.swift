import AppKit
import ApplicationServices
import Foundation

/// Best-effort active URL/host for Safari and Chrome.
/// Prefers AppleScript; falls back to Accessibility document URL when available.
/// Requires Accessibility (and may prompt for Automation) — see README.
enum BrowserURLResolver {
    private static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "company.thebrowser.Browser", // Arc
        "com.brave.Browser",
        "com.microsoft.edgemac",
    ]

    static func isBrowser(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return browserBundleIDs.contains(bundleID)
    }

    static func activeHost(for bundleID: String?) -> String? {
        guard let bundleID, isBrowser(bundleID: bundleID) else { return nil }
        if let urlString = appleScriptURL(for: bundleID) ?? accessibilityURL(),
           let host = host(from: urlString) {
            return host
        }
        return nil
    }

    private static func host(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let host = url.host, !host.isEmpty {
            return host.lowercased()
        }
        // Some AX returns omit scheme
        if let url = URL(string: "https://\(trimmed)"), let host = url.host {
            return host.lowercased()
        }
        return nil
    }

    private static func appleScriptURL(for bundleID: String) -> String? {
        let script: String
        switch bundleID {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
              if (count of windows) is 0 then return ""
              return URL of current tab of front window
            end tell
            """
        case "com.google.Chrome", "com.google.Chrome.canary":
            script = """
            tell application "Google Chrome"
              if (count of windows) is 0 then return ""
              return URL of active tab of front window
            end tell
            """
        case "com.brave.Browser":
            script = """
            tell application "Brave Browser"
              if (count of windows) is 0 then return ""
              return URL of active tab of front window
            end tell
            """
        case "com.microsoft.edgemac":
            script = """
            tell application "Microsoft Edge"
              if (count of windows) is 0 then return ""
              return URL of active tab of front window
            end tell
            """
        default:
            // Arc and others: rely on Accessibility
            return nil
        }
        return runAppleScript(script)
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        let string = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (string?.isEmpty == false) ? string : nil
    }

    private static func accessibilityURL() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appResult == .success, let focusedApp else { return nil }
        let appElement = focusedApp as! AXUIElement

        var focusedWindow: CFTypeRef?
        let winResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )
        guard winResult == .success, let focusedWindow else { return nil }
        let window = focusedWindow as! AXUIElement

        // Try document attribute (often the URL for browsers)
        if let doc = copyStringAttribute(window, "AXDocument") {
            return doc
        }
        if let url = copyStringAttribute(window, "AXURL") {
            return url
        }

        // Walk focused UI element for URL-like attributes
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success, let focused {
            let el = focused as! AXUIElement
            if let doc = copyStringAttribute(el, "AXDocument") { return doc }
            if let url = copyStringAttribute(el, "AXURL") { return url }
        }
        return nil
    }

    private static func copyStringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard result == .success, let value else { return nil }
        if let s = value as? String { return s }
        if CFGetTypeID(value) == CFURLGetTypeID() {
            return (value as! URL).absoluteString
        }
        return nil
    }
}
