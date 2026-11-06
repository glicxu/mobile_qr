"""Independently decode PNGs emitted by barcode_generation_test.dart."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / '.dart_tool/barcode-fixture-verifier'))
import zxingcpp
from PIL import Image

folder = ROOT / '.dart_tool/generated-barcode-qa'
fixtures = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))['fixtures']
formats = dict(upcA=zxingcpp.BarcodeFormat.UPCA, upcE=zxingcpp.BarcodeFormat.UPCE,
               ean8=zxingcpp.BarcodeFormat.EAN8, ean13=zxingcpp.BarcodeFormat.EAN13,
               code128=zxingcpp.BarcodeFormat.Code128, code39=zxingcpp.BarcodeFormat.Code39,
               code93=zxingcpp.BarcodeFormat.Code93, codabar=zxingcpp.BarcodeFormat.Codabar,
               itf14=zxingcpp.BarcodeFormat.ITF, dataMatrix=zxingcpp.BarcodeFormat.DataMatrix,
               pdf417=zxingcpp.BarcodeFormat.PDF417, aztec=zxingcpp.BarcodeFormat.Aztec)
for fixture in fixtures:
    with Image.open(folder / fixture['file']) as image:
        results = zxingcpp.read_barcodes(image, formats=formats[fixture['format']])
    assert len(results) == 1, (fixture['id'], 'symbol count', len(results))
    assert results[0].format == formats[fixture['format']], fixture['id']
    assert results[0].text == fixture['value'], (fixture['id'], repr(results[0].text))
    print('PASS', fixture['id'])
assert len({f['format'] for f in fixtures}) == 12
print('Independent exact decoding passed:', len(fixtures), 'generated PNGs across all 12 additional formats.')
