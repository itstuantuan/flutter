import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions) {
    if let response = connectionOptions.notificationResponse,
       let delegate = UIApplication.shared.delegate as? AppDelegate {
      delegate.captureNotification(response)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
