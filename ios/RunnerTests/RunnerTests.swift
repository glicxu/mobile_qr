import Vision
import XCTest

class RunnerTests: XCTestCase {

  func testSharedValuesArePreservedExactly() {
    let values = ["  exact payload\n", "0012345678905", "   "]
    for value in values {
      let codes = SharedCodePolicy.extract([.init(symbology: .qr, value: value)])
      XCTAssertEqual(codes, [.init(value: value, format: "qrCode")])
    }
  }

  func testSupportedNativeFormatsMapToStableKeys() {
    let expected: [(VNBarcodeSymbology, String)] = [
      (.qr, "qrCode"), (.upce, "upcE"), (.ean8, "ean8"),
      (.ean13, "ean13"), (.code128, "code128"), (.code39, "code39"),
      (.code93, "code93"), (.codabar, "codabar"), (.itf14, "itf14"),
      (.dataMatrix, "dataMatrix"), (.pdf417, "pdf417"), (.aztec, "aztec"),
    ]
    for (symbology, key) in expected {
      XCTAssertEqual(
        SharedCodePolicy.extract([.init(symbology: symbology, value: "00123")]),
        [.init(value: "00123", format: key)]
      )
    }
  }

  func testUnsupportedAndMissingValuesAreDiscarded() {
    let codes = SharedCodePolicy.extract([
      .init(symbology: .i2of5, value: "123456"),
      .init(symbology: .code39FullASCII, value: "variant"),
      .init(symbology: VNBarcodeSymbology(rawValue: "future-qr"), value: "unknown"),
      .init(symbology: .qr, value: nil),
      .init(symbology: .qr, value: ""),
    ])
    XCTAssertTrue(codes.isEmpty)
  }

  func testResultsAreDeduplicatedAndSortedByFormatThenValue() {
    let codes = SharedCodePolicy.extract([
      .init(symbology: .code128, value: "b"),
      .init(symbology: .qr, value: "z"),
      .init(symbology: .code128, value: "a"),
      .init(symbology: .code128, value: "a"),
      .init(symbology: .qr, value: "a"),
    ])
    XCTAssertEqual(codes, [
      .init(value: "a", format: "qrCode"),
      .init(value: "z", format: "qrCode"),
      .init(value: "a", format: "code128"),
      .init(value: "b", format: "code128"),
    ])
  }

  func testCanonicallyEquivalentPayloadsRemainDistinct() {
    let codes = SharedCodePolicy.extract([
      .init(symbology: .qr, value: "\u{00E9}"),
      .init(symbology: .qr, value: "e\u{0301}"),
    ])
    XCTAssertEqual(codes.count, 2)
    XCTAssertEqual(Array(codes[0].value.utf16), [0x65, 0x301])
    XCTAssertEqual(Array(codes[1].value.utf16), [0xE9])
  }

}
