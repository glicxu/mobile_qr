import Flutter
import UIKit
import Contacts
import ContactsUI
import EventKit
import EventKitUI
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
    CNContactViewControllerDelegate, EKEventEditViewDelegate {
  private var qrClipboardChannel: FlutterMethodChannel?
  private var qrRoutingChannel: FlutterMethodChannel?
  private var inboundShareChannel: FlutterMethodChannel?
  private var localStorageChannel: FlutterMethodChannel?
  private let eventStore = EKEventStore()
  private let sharedAppGroup = "group.com.dalifin.qr.shared"
  private let sharedImageKey = "pendingSharedImagePath"
  private let sharedCodePrefix = "dali_shared_code_"
  private let legacySharedQrPrefix = "dali_shared_qr_"
  private var pendingWifiJoin: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    cleanupStaleSharedImages(excluding: pendingSharedImagePath())
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QrClipboard") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "dali_qr/clipboard",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "copyPng" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let bytes = arguments["bytes"] as? FlutterStandardTypedData,
        let payload = arguments["payload"] as? String
      else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "PNG bytes and payload are required.",
          details: nil
        ))
        return
      }
      UIPasteboard.general.items = [[
        "public.png": bytes.data,
        "public.utf8-plain-text": payload,
      ]]
      result(nil)
    }
    qrClipboardChannel = channel

    let storageChannel = FlutterMethodChannel(name: "dali_qr/local_storage", binaryMessenger: registrar.messenger())
    storageChannel.setMethodCallHandler { call, result in
      guard call.method == "batchDatabasePath" || call.method == "paymentsDatabasePath" else { result(FlutterMethodNotImplemented); return }
      let payments = call.method == "paymentsDatabasePath"
      do {
        let manager = FileManager.default
        var directory = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true).appendingPathComponent(payments ? "DaliPayments" : "DaliBatch", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
          attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let file = directory.appendingPathComponent(payments ? "payments.sqlite" : "batch.sqlite")
        if !manager.fileExists(atPath: file.path) {
          guard manager.createFile(atPath: file.path, contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication, .posixPermissions: 0o600]) else {
            throw NSError(domain: "DaliLocalStorage", code: 1)
          }
        }
        try manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
          .posixPermissions: 0o600], ofItemAtPath: file.path)
        result(file.path)
      } catch {
        result(FlutterError(code: "storage_unavailable", message: "Protected local storage is unavailable.", details: nil))
      }
    }
    localStorageChannel = storageChannel

    let routingChannel = FlutterMethodChannel(
      name: "dali_qr/routing",
      binaryMessenger: registrar.messenger()
    )
    routingChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      let arguments = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "wifiJoinCapabilities":
        result(["securityTypes": ["open", "wpa2"], "canOpenSettings": false])
      case "joinWifi":
        self.joinWifi(arguments, result: result)
      case "authenticatePasskey":
        guard let raw = arguments["uri"] as? String,
              raw.range(of: "^FIDO:/[0-9]+$", options: .regularExpression) != nil,
              let url = URL(string: raw) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      case "configureWifi":
        result(false)
      case "addContact":
        let contact = CNMutableContact()
        contact.givenName = arguments["name"] as? String ?? ""
        if let phone = arguments["phone"] as? String {
          contact.phoneNumbers = [CNLabeledValue(
            label: CNLabelPhoneNumberMain,
            value: CNPhoneNumber(stringValue: phone)
          )]
        }
        if let email = arguments["email"] as? String {
          contact.emailAddresses = [CNLabeledValue(
            label: CNLabelHome,
            value: email as NSString
          )]
        }
        let controller = CNContactViewController(forNewContact: contact)
        controller.contactStore = CNContactStore()
        controller.delegate = self
        self.present(UINavigationController(rootViewController: controller))
        result(true)
      case "addCalendarEvent":
        let event = EKEvent(eventStore: self.eventStore)
        event.title = arguments["title"] as? String
        event.location = arguments["location"] as? String
        event.notes = arguments["description"] as? String
        if let millis = arguments["startMillis"] as? NSNumber {
          event.startDate = Date(timeIntervalSince1970: millis.doubleValue / 1000)
        }
        if let millis = arguments["endMillis"] as? NSNumber {
          event.endDate = Date(timeIntervalSince1970: millis.doubleValue / 1000)
        } else if let start = event.startDate {
          event.endDate = start.addingTimeInterval(3600)
        }
        let controller = EKEventEditViewController()
        controller.eventStore = self.eventStore
        controller.event = event
        controller.editViewDelegate = self
        self.present(controller)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    qrRoutingChannel = routingChannel

    let inboundChannel = FlutterMethodChannel(
      name: "dali_qr/inbound_share",
      binaryMessenger: registrar.messenger()
    )
    inboundChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "takeInitialImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.takePendingSharedImage())
    }
    inboundShareChannel = inboundChannel
  }

  private func joinWifi(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard pendingWifiJoin == nil else { result("busy"); return }
    guard UIApplication.shared.applicationState == .active,
          let ssid = arguments["ssid"] as? String,
          !ssid.isEmpty, ssid.utf8.count <= 32,
          !ssid.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
          let security = arguments["security"] as? String else { result("failed"); return }
    let password = arguments["password"] as? String ?? ""
    let configuration: NEHotspotConfiguration
    switch security {
    case "open":
      guard password.isEmpty else { result("failed"); return }
      configuration = NEHotspotConfiguration(ssid: ssid)
    case "wpa2":
      guard (8...63).contains(password.utf8.count),
            password.unicodeScalars.allSatisfy({ (32...126).contains($0.value) }) else { result("failed"); return }
      configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
    default:
      result("unsupported")
      return
    }
    configuration.hidden = arguments["hidden"] as? Bool ?? false
    configuration.joinOnce = false
    pendingWifiJoin = result
    NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
      DispatchQueue.main.async {
        guard let self, let callback = self.pendingWifiJoin else { return }
        self.pendingWifiJoin = nil
        guard let error = error as NSError? else { callback("accepted"); return }
        if error.domain == NEHotspotConfigurationErrorDomain {
          switch error.code {
          case NEHotspotConfigurationError.userDenied.rawValue: callback("cancelled")
          case NEHotspotConfigurationError.alreadyAssociated.rawValue: callback("alreadyAssociated")
          case NEHotspotConfigurationError.pending.rawValue: callback("busy")
          default: callback("failed")
          }
        } else { callback("failed") }
      }
    }
  }

  func notifySharedImageAvailable() {
    guard let path = pendingSharedImagePath() else { return }
    inboundShareChannel?.invokeMethod("sharedImage", arguments: path) {
      [weak self] result in
      if result == nil {
        self?.clearPendingSharedImage(path)
      }
    }
  }

  private func pendingSharedImagePath() -> String? {
    guard
      let path = UserDefaults(suiteName: sharedAppGroup)?.string(forKey: sharedImageKey),
      FileManager.default.fileExists(atPath: path)
    else { return nil }
    return path
  }

  private func takePendingSharedImage() -> String? {
    guard let path = pendingSharedImagePath() else { return nil }
    clearPendingSharedImage(path)
    return path
  }

  private func clearPendingSharedImage(_ path: String) {
    guard
      UserDefaults(suiteName: sharedAppGroup)?.string(forKey: sharedImageKey) == path
    else { return }
    UserDefaults(suiteName: sharedAppGroup)?.removeObject(forKey: sharedImageKey)
  }

  private func cleanupStaleSharedImages(excluding retainedPath: String?) {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: sharedAppGroup
      ),
      let files = try? FileManager.default.contentsOfDirectory(
        at: container,
        includingPropertiesForKeys: nil
      )
    else { return }
    for file in files where
      file.path != retainedPath &&
      (file.lastPathComponent.hasPrefix(sharedCodePrefix) ||
       file.lastPathComponent.hasPrefix(legacySharedQrPrefix)) {
      try? FileManager.default.removeItem(at: file)
    }
  }

  func contactViewController(
    _ viewController: CNContactViewController,
    didCompleteWith contact: CNContact?
  ) {
    viewController.navigationController?.dismiss(animated: true)
  }

  func eventEditViewController(
    _ controller: EKEventEditViewController,
    didCompleteWith action: EKEventEditViewAction
  ) {
    controller.dismiss(animated: true)
  }

  private func present(_ controller: UIViewController) {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first
    var presenter = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = presenter?.presentedViewController {
      presenter = presented
    }
    presenter?.present(controller, animated: true)
  }
}
