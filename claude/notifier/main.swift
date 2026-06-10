import AppKit
import UserNotifications

// ClaudeNotifier — a tiny notifier built around UNUserNotificationCenter.
//
// Post mode (invoked by the notify hook):
//   ClaudeNotifier -message "..." [-title "..."] [-subtitle "..."]
//                  [-sound Glass] [-activate com.microsoft.VSCode]
//
// Click mode: when the user clicks a notification after this process has
// exited, macOS relaunches the app with no arguments and delivers the
// response to the delegate, which activates the bundle id stored in the
// notification's userInfo.

func value(after flag: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
        return nil
    }
    return args[index + 1]
}

let message = value(after: "-message")
let titleArg = value(after: "-title") ?? "Claude"
let subtitleArg = value(after: "-subtitle")
let soundArg = value(after: "-sound")
let activateArg = value(after: "-activate")

func exitSoon(_ seconds: Double) {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exit(0) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let body = message {
            post(body: body)
        } else {
            // Launched by a notification click; wait for didReceive below.
            exitSoon(5)
        }
    }

    private func post(body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
            let content = UNMutableNotificationContent()
            content.title = titleArg
            if let subtitle = subtitleArg {
                content.subtitle = subtitle
            }
            content.body = body
            if let sound = soundArg {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            }
            if let bundleID = activateArg {
                content.userInfo["activate"] = bundleID
            }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request) { _ in
                // Give the notification a moment to hand off before exiting.
                exitSoon(0.3)
            }
        }
        // Safety net in case authorization never calls back.
        exitSoon(10)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard let bundleID = userInfo["activate"] as? String,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else {
            exitSoon(0.2)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { exit(0) }
        }
        exitSoon(5)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        completionHandler([.banner, .sound])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// The delegate must be in place before the app finishes launching so click
// relaunches deliver their notification response.
UNUserNotificationCenter.current().delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
