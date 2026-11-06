"""Independently decode synthetic PNGs emitted by structured_qr_creation_test."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / '.dart_tool/barcode-fixture-verifier'))
import zxingcpp
from PIL import Image

folder = ROOT / '.dart_tool/structured-qr-qa'
fixtures = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
assert {f['type'] for f in fixtures} == {'contact', 'event', 'location', 'email', 'phone', 'sms'}
for fixture in fixtures:
    with Image.open(folder / fixture['file']) as image:
        results = zxingcpp.read_barcodes(image, formats=zxingcpp.BarcodeFormat.QRCode)
    assert len(results) == 1, fixture['type']
    assert results[0].text == fixture['payload'], fixture['type']
    print('PASS', fixture['type'])
print('Independent exact QR decoding passed: six structured payload types.')
