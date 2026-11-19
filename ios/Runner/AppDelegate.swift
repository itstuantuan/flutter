import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var pendingNotifications = [[String: String]]()
  private var pushToken: String?
  private var registrationError: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ViitorPush")!
    let channel = FlutterMethodChannel(name: "viitor/apns", binaryMessenger: registrar.messenger())
    pushChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "status": self.pushStatus(result)
      case "takeNotification":
        result(self.pendingNotifications.isEmpty ? nil : self.pendingNotifications.removeFirst())
      case "clearNotifications":
        self.pendingNotifications.removeAll()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        result(nil)
      case "requestPermission":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
          DispatchQueue.main.async {
            if error != nil {
              result(FlutterError(code: "authorization_failed", message: "通知授权请求失败", details: nil))
              return
            }
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            self.pushStatus(result)
          }
        }
      case "register":
        self.registrationError = nil
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      case "openSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func pushStatus(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        let status: String
        switch settings.authorizationStatus {
        case .authorized: status = "authorized"
        case .denied: status = "denied"
        case .provisional: status = "provisional"
        case .ephemeral: status = "ephemeral"
        default: status = "notDetermined"
        }
        result(["authorization": status, "token": self.pushToken ?? "",
                "registrationError": self.registrationError ?? "",
                "environment": self.apnsEnvironment() ?? ""])
      }
    }
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    pushToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    registrationError = nil
    pushChannel?.invokeMethod("registrationChanged", arguments: nil)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    pushToken = nil
    registrationError = "APNs 注册失败，请检查推送签名配置和网络后重试。"
    pushChannel?.invokeMethod("registrationChanged", arguments: nil)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list, .sound])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
    captureNotification(response)
    completionHandler()
  }

  func captureNotification(_ response: UNNotificationResponse) {
    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
    let info = response.notification.request.content.userInfo
    let payload: [String: String]
    if info["event"] as? String == "exploration_completed",
       let task = info["taskId"] as? String, !task.isEmpty,
       let session = info["sessionId"] as? String, !session.isEmpty,
       let notification = info["notificationId"] as? String, !notification.isEmpty {
      payload = ["event": "exploration_completed", "taskId": task,
                 "sessionId": session, "notificationId": notification, "source": "remote"]
    } else {
      let request = response.notification.request
      let id = "\(request.identifier):\(response.notification.date.timeIntervalSince1970)"
      payload = ["event": "home", "notificationId": id, "source": "remote"]
    }
    if !pendingNotifications.contains(payload) {
      pendingNotifications.append(payload)
      if pendingNotifications.count > 32 { pendingNotifications.removeFirst() }
    }
    pushChannel?.invokeMethod("notificationOpened", arguments: nil)
  }

  /// Prefer the installed signing profile. Store builds carry the production
  /// setting for installations where Apple removes the profile.
  private func apnsEnvironment() -> String? {
    #if targetEnvironment(simulator)
    return nil
    #else
    if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") {
      guard let data = try? Data(contentsOf: url),
            let start = data.range(of: Data("<?xml".utf8)),
            let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
            let plist = try? PropertyListSerialization.propertyList(
              from: data.subdata(in: start.lowerBound..<end.upperBound), options: [], format: nil),
            let profile = plist as? [String: Any],
            let entitlements = profile["Entitlements"] as? [String: Any],
            let value = entitlements["aps-environment"] as? String else { return nil }
      return value == "development" ? "sandbox" : (value == "production" ? "production" : nil)
    }
    let storeEnvironment = Bundle.main.object(forInfoDictionaryKey: "ViitorAPNsStoreEnvironment") as? String
    return storeEnvironment == "production" ? "production" : nil
    #endif
  }
}
