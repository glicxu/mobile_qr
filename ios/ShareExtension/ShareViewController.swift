import Social

final class ShareViewController: SLComposeServiceViewController {
  private let imageTypeIdentifier = "public.image"
  private let appGroup = "group.com.dalifin.qr.shared"
  private let sharedImageKey = "pendingSharedImagePath"

  override func isContentValid() -> Bool { true }

  override func didSelectPost() {
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let provider = item.attachments?.first(where: {
        $0.hasItemConformingToTypeIdentifier(imageTypeIdentifier)
      })
    else {
      finish()
      return
    }

    provider.loadFileRepresentation(forTypeIdentifier: imageTypeIdentifier) {
      [weak self] sourceURL, _ in
      guard let self, let sourceURL else {
        self?.finish()
        return
      }
      self.storeAndOpen(sourceURL)
    }
  }

  override func configurationItems() -> [Any]! { [] }

  private func storeAndOpen(_ sourceURL: URL) {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup
      ),
      let defaults = UserDefaults(suiteName: appGroup)
    else {
      finish()
      return
    }

    if let oldPath = defaults.string(forKey: sharedImageKey) {
      try? FileManager.default.removeItem(atPath: oldPath)
    }
    let suffix = sourceURL.pathExtension.isEmpty ? "image" : sourceURL.pathExtension
    let destination = container
      .appendingPathComponent("dali_shared_qr_\(UUID().uuidString)")
      .appendingPathExtension(suffix)
    do {
      try FileManager.default.copyItem(at: sourceURL, to: destination)
      defaults.set(destination.path, forKey: sharedImageKey)
      DispatchQueue.main.async { [weak self] in
        self?.openContainingApp()
        self?.finish()
      }
    } catch {
      finish()
    }
  }

  private func openContainingApp() {
    guard let url = URL(string: "daliqr://shared-image") else { return }
    var responder: UIResponder? = self
    let selector = sel_registerName("openURL:")
    while let current = responder {
      if current.responds(to: selector) {
        current.perform(selector, with: url)
        return
      }
      responder = current.next
    }
  }

  private func finish() {
    DispatchQueue.main.async { [weak self] in
      self?.extensionContext?.completeRequest(returningItems: nil)
    }
  }
}
