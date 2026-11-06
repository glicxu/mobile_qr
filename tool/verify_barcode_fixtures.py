"""Independently decode committed fixtures using zxing-cpp and Pillow."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / '.dart_tool/barcode-fixture-verifier'))
import zxingcpp
from PIL import Image

directory = ROOT / ('test/fixtures/optional_formats' if '--optional' in sys.argv else 'test/fixtures/barcodes')
manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8'))
formats = {
    'dataMatrix': zxingcpp.BarcodeFormat.DataMatrix,
    'pdf417': zxingcpp.BarcodeFormat.PDF417,
    'aztec': zxingcpp.BarcodeFormat.Aztec,
    'qrCode': zxingcpp.BarcodeFormat.QRCode,
    'upcA': zxingcpp.BarcodeFormat.UPCA,
    'upcE': zxingcpp.BarcodeFormat.UPCE,
    'ean8': zxingcpp.BarcodeFormat.EAN8,
    'ean13': zxingcpp.BarcodeFormat.EAN13,
    'code128': zxingcpp.BarcodeFormat.Code128,
    'code39': zxingcpp.BarcodeFormat.Code39,
    'code93': zxingcpp.BarcodeFormat.Code93,
    'codabar': zxingcpp.BarcodeFormat.Codabar,
    'itf14': zxingcpp.BarcodeFormat.ITF,
}
failures = []
for fixture in manifest['fixtures']:
    file = directory / fixture.get('file', fixture['id'] + '.png')
    format_key = fixture.get('symbolFormat', fixture.get('format'))
    value = fixture.get('encodedValue', fixture.get('value'))
    try:
        assert hashlib.sha256(file.read_bytes()).hexdigest() == fixture['sha256'], 'hash mismatch'
        with Image.open(file) as image:
            results = zxingcpp.read_barcodes(image, formats=formats[format_key])
        assert len(results) == 1, f'expected one symbol, got {len(results)}'
        result = results[0]
        assert result.format == formats[format_key], f'format: {result.format}'
        assert result.text == value, f'value: {result.text!r}'
        print(f"PASS {fixture['id']}")
    except (AssertionError, OSError) as error:
        failures.append(f"{fixture['id']}: {error}")
if failures:
    raise SystemExit('\n'.join(failures))
print(f"Independent decoding passed: {len(manifest['fixtures'])} fixtures. Not native-device QA.")
