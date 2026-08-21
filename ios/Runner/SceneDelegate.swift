import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    guard URLContexts.contains(where: { $0.url.scheme == "daliqr" }) else {
      return
    }
    (UIApplication.shared.delegate as? AppDelegate)?.notifySharedImageAvailable()
  }
}
