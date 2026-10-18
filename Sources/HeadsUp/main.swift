// Heads Up: posts a macOS notification for Claude Code and opens a link when it is clicked.
//
//   "Heads Up.app/Contents/MacOS/HeadsUp" --title T [--subtitle S] [--body B]
//       [--url claude://...] [--activate com.apple.Terminal] [--id ID] [--quiet]
//   "Heads Up.app/Contents/MacOS/HeadsUp" --clear ID[,ID...]
//
// The hook script (heads-up-notify.py) decides when to call this. A click launches the
// app with no arguments; macOS hands it the clicked notification, it opens the stored
// link (or brings the stored app forward), then quits.
import AppKit
import UserNotifications

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: "--" + name), i + 1 < a.count else { return nil }
    return a[i + 1]
}

/// The installer copies the system Hero sound into the bundle; fall back to the default sound.
func alertSound() -> UNNotificationSound {
    if Bundle.main.url(forResource: "Hero", withExtension: "aiff") != nil {
        return UNNotificationSound(named: UNNotificationSoundName("Hero.aiff"))
    }
    return .default
}

final class Delegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let center = UNUserNotificationCenter.current()

    func applicationWillFinishLaunching(_ note: Notification) {
        center.delegate = self  // must be set before launch finishes to receive the click
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        if let id = arg("clear") {
            center.removeDeliveredNotifications(withIdentifiers: id.components(separatedBy: ","))
            quit(after: 0.5)
        } else if let title = arg("title") {
            post(title: title)
        } else {
            quit(after: 10)  // launched by a click, wait for macOS to deliver it
        }
    }

    func post(title: String) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return self.quit(after: 0) }
            let content = UNMutableNotificationContent()
            content.title = title
            if let s = arg("subtitle") { content.subtitle = s }
            if let b = arg("body") { content.body = b }
            if CommandLine.arguments.contains("--quiet") == false {
                content.sound = alertSound()
            }
            var info: [String: String] = [:]
            if let u = arg("url") { info["url"] = u }
            if let b = arg("activate") { info["activate"] = b }
            content.userInfo = info
            content.interruptionLevel = .timeSensitive
            let id = arg("id") ?? UUID().uuidString
            content.threadIdentifier = id
            self.center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { _ in
                self.quit(after: 1)
            }
        }
    }

    func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        DispatchQueue.main.async {
            if let s = info["url"] as? String, let url = URL(string: s) {
                NSWorkspace.shared.open(url)
            } else if let bundle = info["activate"] as? String,
                      let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
                NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
            }
            done()
            self.quit(after: 1)
        }
    }

    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .list, .sound])
    }

    func quit(after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited)
app.run()
