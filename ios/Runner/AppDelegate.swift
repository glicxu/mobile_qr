import Flutter
import UIKit
import Contacts
import ContactsUI
import EventKit
import EventKitUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
    CNContactViewControllerDelegate, EKEventEditViewDelegate {
  private var qrClipboardChannel: FlutterMethodChannel?
  private var qrRoutingChannel: FlutterMethodChannel?
  private var inboundShareChannel: FlutterMethodChannel?
  private let eventStore = EKEventStore()
  private let sharedAppGroup = "group.com.dalifin.qr.shared"
  private let sharedImageKey = "pendingSharedImagePath"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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

    let routingChannel = FlutterMethodChannel(
      name: "dali_qr/routing",
      binaryMessenger: registrar.messenger()
    )
    routingChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      let arguments = call.arguments as? [String: Any] ?? [:]
      switch call.method {
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
