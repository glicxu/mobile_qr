import Vision

/// Keeps native share results aligned with the Flutter scanner boundary.
enum SharedCodePolicy {
  struct Input {
    let symbology: VNBarcodeSymbology
    let value: String?
  }

  struct Code: Encodable, Equatable {
    let value: String
    let format: String
  }

  // Vision reports UPC-A as EAN-13. Preserve that format and its leading zero.
  static let formats: [(symbology: VNBarcodeSymbology, key: String)] = [
    (.qr, "qrCode"),
    (.upce, "upcE"),
    (.ean8, "ean8"),
    (.ean13, "ean13"),
    (.code128, "code128"),
    (.code39, "code39"),
    (.code93, "code93"),
    (.codabar, "codabar"),
    (.itf14, "itf14"),
    (.dataMatrix, "dataMatrix"),
    (.pdf417, "pdf417"),
    (.aztec, "aztec"),
  ]

  static func extract(_ inputs: [Input]) -> [Code] {
    var seen = Set<[UInt16]>()
    var codes: [Code] = []
    for input in inputs {
      guard
        let value = input.value,
        !value.isEmpty,
        let format = formats.first(where: { $0.symbology == input.symbology })?.key
      else { continue }
      // Length-prefix the format so payload contents cannot create key collisions.
      let identity = "\(format.count):\(format)\(value)"
      guard seen.insert(Array(identity.utf16)).inserted else { continue }
      codes.append(Code(value: value, format: format))
    }
    let priorities = Dictionary(uniqueKeysWithValues: formats.enumerated().map {
      ($0.element.key, $0.offset)
    })
    return codes.sorted {
      let left = priorities[$0.format]!
      let right = priorities[$1.format]!
      // Match Dart String.compareTo (UTF-16 code-unit order).
      return left == right
        ? $0.value.utf16.lexicographicallyPrecedes($1.value.utf16)
        : left < right
    }
  }
}
