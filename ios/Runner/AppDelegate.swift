import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var pendingNotification: [String: String]?
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
      case "scheduleDemo":
        #if DEBUG
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
          guard granted, error == nil else {
            DispatchQueue.main.async { result(FlutterError(code: "permission_denied", message: "请在系统设置中允许通知后重试", details: nil)) }
            return
          }
          let content = UNMutableNotificationContent()
          content.title = "模拟发现已准备好"
          content.body = "点击查看本地测试发现（不经过 APNs）"
          content.sound = .default
          content.userInfo = ["type": "discovery", "discoveryId": "local-demo-discovery", "source": "local-demo"]
          let request = UNNotificationRequest(identifier: "viitor-local-demo", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
          UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
              if error != nil {
                result(FlutterError(code: "schedule_failed", message: "本地通知安排失败，请重试", details: nil))
              } else { result(nil) }
            }
          }
        }
        #else
        result(FlutterMethodNotImplemented)
        #endif
      case "status": self.pushStatus(result)
      case "takeNotification":
        result(self.pendingNotification)
        self.pendingNotification = nil
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
                "registrationError": self.registrationError ?? ""])
      }
    }
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    pushToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    #if DEBUG
    if let token = pushToken {
      print("[APNs] device token: \(token)")
    }
    #endif
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
    let info = response.notification.request.content.userInfo
    if let type = info["type"] as? String, type == "discovery",
       let id = info["discoveryId"] as? String, !id.isEmpty {
      pendingNotification = ["type": type, "discoveryId": id, "source": info["source"] as? String ?? "remote"]
      pushChannel?.invokeMethod("notificationOpened", arguments: nil)
    }
  }

}
