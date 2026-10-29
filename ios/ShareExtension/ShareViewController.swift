import Flutter
import UIKit
import Vision

final class ShareViewController: UIViewController {
  private struct DetectedCode: Encodable {
    let value: String
    let format: String
  }

  private let imageTypeIdentifier = "public.image"
  private let maxSharedImageBytes = 25 * 1024 * 1024
  private var hasStarted = false
  private var flutterEngine: FlutterEngine?
  private var flutterChannel: FlutterMethodChannel?

  private let spinner = UIActivityIndicatorView(style: .medium)
  private let statusLabel = UILabel()
  private let doneButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.startAnimating()

    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.text = "Reading QR codes and barcodes…"
    statusLabel.font = .preferredFont(forTextStyle: .headline)
    statusLabel.numberOfLines = 0
    statusLabel.textAlignment = .center

    doneButton.translatesAutoresizingMaskIntoConstraints = false
    doneButton.setTitle("Done", for: .normal)
    doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
    doneButton.isHidden = true

    let stack = UIStackView(arrangedSubviews: [spinner, statusLabel, doneButton])
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 14
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !hasStarted else { return }
    hasStarted = true
    readSharedImage()
  }

  private func readSharedImage() {
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let provider = item.attachments?.first(where: {
        $0.hasItemConformingToTypeIdentifier(imageTypeIdentifier)
      })
    else {
      showError("Dali QR could not find an image in this share.")
      return
    }

    provider.loadDataRepresentation(forTypeIdentifier: imageTypeIdentifier) {
      [weak self] imageData, error in
      guard let self, let imageData else {
        self?.showError(error?.localizedDescription ?? "Dali QR could not load the shared image.")
        return
      }
      guard imageData.count <= self.maxSharedImageBytes else {
        self.showError("This image is larger than the 25 MB sharing limit.")
        return
      }
      self.scanImage(imageData)
    }
  }

  private func scanImage(_ imageData: Data) {
    let request = VNDetectBarcodesRequest { [weak self] request, error in
      guard let self else { return }
      if let error {
        self.showError(error.localizedDescription)
        return
      }

      let observations = request.results as? [VNBarcodeObservation] ?? []
      var seen = Set<String>()
      let codes = observations.compactMap { observation -> DetectedCode? in
        guard
          let value = observation.payloadStringValue?.trimmingCharacters(
            in: .whitespacesAndNewlines
          ),
          !value.isEmpty
        else { return nil }
        let format = self.storageKey(for: observation.symbology.rawValue)
        let key = "\(format)\u{0}\(value)"
        guard seen.insert(key).inserted else { return nil }
        return DetectedCode(value: value, format: format)
      }
      self.showFlutterResults(codes)
    }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do {
        try VNImageRequestHandler(data: imageData, options: [:]).perform([request])
      } catch {
        self?.showError(error.localizedDescription)
      }
    }
  }

  private func storageKey(for rawValue: String) -> String {
    let value = rawValue.lowercased()
    if value.contains("qr") { return "qrCode" }
    if value.contains("upce") { return "upcE" }
    if value.contains("ean8") { return "ean8" }
    if value.contains("ean13") { return "ean13" }
    if value.contains("code128") { return "code128" }
    if value.contains("code39") { return "code39" }
    if value.contains("code93") { return "code93" }
    if value.contains("codabar") { return "codabar" }
    if value.contains("itf14") || value.contains("i2of5") { return "itf14" }
    return "unknown"
  }

  private func showFlutterResults(_ codes: [DetectedCode]) {
    guard
      let json = try? JSONEncoder().encode(codes)
    else {
      showError("Dali QR could not prepare the scan results.")
      return
    }
    let encoded = json.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    let route = "/share-result?data=\(encoded)"

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let containingAppURL = Bundle.main.bundleURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
      let appFrameworkURL = containingAppURL
        .appendingPathComponent("Frameworks")
        .appendingPathComponent("App.framework")
      guard let appBundle = Bundle(url: appFrameworkURL), appBundle.load() else {
        self.showError("Dali QR could not load its result interface.")
        return
      }
      let project = FlutterDartProject(precompiledDartBundle: appBundle)
      let engine = FlutterEngine(
        name: "dali-qr-share-extension",
        project: project,
        allowHeadlessExecution: false
      )
      guard engine.run(
        withEntrypoint: "shareExtensionMain",
        libraryURI: nil,
        initialRoute: route,
        entrypointArgs: nil
      ) else {
        self.showError("Dali QR could not open its result view.")
        return
      }

      let channel = FlutterMethodChannel(
        name: "dali_qr/share_extension",
        binaryMessenger: engine.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "finish" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(nil)
        self?.finish()
      }

      let flutterViewController = FlutterViewController(
        engine: engine,
        nibName: nil,
        bundle: nil
      )
      self.flutterEngine = engine
      self.flutterChannel = channel
      self.addChild(flutterViewController)
      flutterViewController.view.translatesAutoresizingMaskIntoConstraints = false
      self.view.addSubview(flutterViewController.view)
      NSLayoutConstraint.activate([
        flutterViewController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
        flutterViewController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        flutterViewController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
        flutterViewController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      ])
      flutterViewController.didMove(toParent: self)
    }
  }

  private func showError(_ message: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.spinner.stopAnimating()
      self.spinner.isHidden = true
      self.statusLabel.text = message
      self.doneButton.isHidden = false
    }
  }

  @objc private func finish() {
    flutterChannel?.setMethodCallHandler(nil)
    flutterEngine?.destroyContext()
    extensionContext?.completeRequest(returningItems: nil)
  }
}
