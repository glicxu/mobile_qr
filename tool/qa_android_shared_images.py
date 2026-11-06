"""Physical Android ACTION_SEND QA using a disposable, isolated debug package.

Requires scanner-qa.apk built with --dart-define=DALI_SCANNER_QA_BUILD=true. No existing app
data is cleared. UI dumps are filtered to the QA package and not retained.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = 'com.dalifin.qr.scannerqa'
LABELS = dict(qrCode='QR Code', upcA='UPC-A', upcE='UPC-E', ean8='EAN-8',
              ean13='EAN-13', code128='Code 128', code39='Code 39',
              code93='Code 93', codabar='Codabar', itf14='ITF-14',
              dataMatrix='Data Matrix', pdf417='PDF417', aztec='Aztec')
PAIRS = [
    ('aztec_short', 'aztec_long'), ('qr_url', 'qr_whitespace'),
    ('upca_zero', 'upca_other'), ('upce_example', 'upce_other'),
    ('ean8_example', 'ean8_zero'), ('ean13_book', 'ean13_upca_pair'),
    ('code128_short', 'code128_whitespace'), ('code39_short', 'code39_long'),
    ('code93_short', 'code93_long'), ('codabar_short', 'codabar_long'),
    ('itf14_zero', 'itf14_other'), ('dataMatrix_short', 'dataMatrix_long'),
    ('pdf417_short', 'pdf417_long'),
]


class Device:
    def __init__(self, serial, run_id):
        self.prefix = ['adb', '-s', serial]
        self.remote = '/data/local/tmp/dali_scanner_qa_' + run_id
        self.media_folder = 'Pictures/DaliScannerQA_' + run_id + '/'
        self.last_nodes = []

    def call(self, *args, check=True, timeout=35, input_bytes=None, include_stderr=False):
        result = subprocess.run(self.prefix + list(args), capture_output=True, timeout=timeout, input=input_bytes)
        if check and result.returncode:
            raise RuntimeError('ADB command failed: ' + ' '.join(args[:3]) + ': ' +
                               result.stderr.decode('utf-8', errors='replace')[:300])
        data = result.stdout + (result.stderr if include_stderr else b'')
        return data.decode('utf-8', errors='replace').strip()

    def shell(self, *args, **kwargs):
        return self.call('shell', *args, **kwargs)

    def foreground(self):
        activities = self.shell('dumpsys', 'activity', 'activities')
        return any(PACKAGE in line for line in activities.splitlines() if 'mResumedActivity:' in line)

    def nodes(self):
        if not self.foreground():
            return []
        path = self.remote + '/view.xml'
        self.shell('uiautomator', 'dump', '--compressed', path, timeout=20)
        root = ET.fromstring(self.call('exec-out', 'cat', path))
        self.last_nodes = [dict(node.attrib) for node in root.iter('node') if node.get('package') == PACKAGE]
        return self.last_nodes

    @staticmethod
    def strings(nodes):
        return [node.get(key, '') for node in nodes for key in ['text', 'content-desc'] if node.get(key)]

    def wait(self, predicate, seconds=35):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                nodes = self.nodes()
                if predicate(nodes):
                    return nodes
            except (ET.ParseError, subprocess.TimeoutExpired):
                pass
            time.sleep(.2)
        raise RuntimeError('QA UI did not reach the expected state. QA-only labels: ' +
                           repr(self.strings(self.last_nodes))[:1800])

    @staticmethod
    def bounds(node):
        values = [int(value) for value in re.findall(r'\d+', node.get('bounds', ''))]
        if len(values) != 4:
            return None
        left, top, right, bottom = values
        return (left, top, right, bottom) if right > left and bottom > top else None

    def tap(self, label, scroll=True):
        for _ in range(10 if scroll else 1):
            nodes = self.nodes()
            candidates = [node for node in nodes if self.bounds(node) and
                          any(label in value for value in self.strings([node]))]
            if candidates:
                node = min(candidates, key=lambda item: (self.bounds(item)[2] - self.bounds(item)[0]) *
                           (self.bounds(item)[3] - self.bounds(item)[1]))
                left, top, right, bottom = self.bounds(node)
                self.shell('input', 'tap', str((left + right) // 2), str((top + bottom) // 2))
                return
            if not scroll or not nodes:
                break
            self.scroll(nodes, forward=True)
        raise RuntimeError('QA control not found: ' + label + '; QA-only labels: ' + repr(self.strings(self.last_nodes))[:1800])

    def scroll(self, nodes, forward=True):
        if not self.foreground():
            raise RuntimeError('QA app is no longer in the foreground')
        regions = [self.bounds(node) for node in nodes if self.bounds(node)]
        if not regions:
            raise RuntimeError('No QA view bounds are available')
        left = min(value[0] for value in regions)
        top = min(value[1] for value in regions)
        right = max(value[2] for value in regions)
        bottom = max(value[3] for value in regions)
        lower = top + (bottom - top) * 3 // 4
        upper = top + (bottom - top) // 3
        start, end = (lower, upper) if forward else (upper, lower)
        self.shell('input', 'swipe', str((left + right) // 2), str(start),
                   str((left + right) // 2), str(end), '350')

    def contains(self, nodes, label):
        return any(label in value for value in self.strings(nodes))

    def confirm_action(self, label, confirmation):
        # UIAutomator can miss a transient Snackbar while waiting for Android's
        # clipboard overlay to become idle. These local actions are idempotent.
        for attempt in range(3):
            self.tap(label)
            try:
                return self.wait(lambda nodes: self.contains(nodes, confirmation), seconds=8)
            except RuntimeError:
                if attempt == 2:
                    raise


def load_fixtures():
    fixtures = {}
    for directory in [ROOT / 'test/fixtures/barcodes', ROOT / 'test/fixtures/optional_formats']:
        for fixture in json.loads((directory / 'manifest.json').read_text(encoding='utf-8'))['fixtures']:
            identifier = fixture['id']
            assert re.fullmatch(r'[A-Za-z0-9_]+', identifier)
            path = (directory / fixture.get('file', identifier + '.png')).resolve()
            assert path.is_relative_to(ROOT / 'test/fixtures')
            assert hashlib.sha256(path.read_bytes()).hexdigest() == fixture['sha256']
            fixtures[identifier] = dict(fixture, path=path)
    return fixtures


def fixture_digest(fixture):
    return hashlib.sha256(fixture['path'].read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--apk', type=Path, default=ROOT / 'build/app/outputs/flutter-apk/scanner-qa.apk')
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/qa/evidence/android-real-shares.json')
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--limit', type=int, default=len(PAIRS))
    parser.add_argument('--keep-installed', action='store_true', help='Keep the disposable QA app for investigation.')
    args = parser.parse_args()
    assert 1 <= args.limit <= len(PAIRS)
    apk = args.apk.resolve()
    sdk = Path(os.environ.get('ANDROID_HOME', Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk'))
    aapt = max(sdk.glob('build-tools/*/aapt.exe'), key=lambda value: tuple(map(int, re.findall(r'\d+', value.parent.name))))
    manifest = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)], text=True, encoding='utf-8')
    assert re.search(r"^package: name='" + re.escape(PACKAGE) + "'", manifest), 'Refusing to install a non-QA package'
    device = Device(args.serial, uuid.uuid4().hex[:12])
    assert device.call('get-state') == 'device'
    assert not device.shell('pm', 'path', PACKAGE, check=False), 'QA package already exists; do not overwrite unknown app data'
    fixtures = load_fixtures()
    pairs = PAIRS[:args.limit]
    used = sorted({identifier for pair in pairs for identifier in pair})
    installed = False
    old_airplane = device.shell('settings', 'get', 'global', 'airplane_mode_on')
    old_wifi = device.shell('settings', 'get', 'global', 'wifi_on')
    assert old_airplane in ['0', '1']
    assert old_wifi in ['0', '1', '2', '3']
    outcomes = []
    media_uris = {}
    record = dict(device=args.serial, date=time.strftime('%Y-%m-%d'), scope='Real ACTION_SEND with temporary MediaStore image URIs and read grants; normal Flutter entrypoint',
                  freshInstall=True, temporaryMediaFolder=device.media_folder, offline=args.offline, cases=outcomes, apkSha256=hashlib.sha256(apk.read_bytes()).hexdigest(),
                  limitations=['Exercises MediaStore URI grants; does not exercise third-party Photos/Files/messaging share chooser UI.',
                               'Does not validate optical live-camera capture or the real image picker.',
                               'Clipboard API completion is observed; global clipboard contents are not read.'])
    try:
        device.call('install', str(apk), timeout=90)
        installed = True
        device.shell('mkdir', '-p', device.remote)
        if args.offline:
            device.shell('cmd', 'connectivity', 'airplane-mode', 'enable')
            device.shell('svc', 'wifi', 'disable')
            defaults = []
            for _ in range(12):
                time.sleep(1)
                connectivity = device.shell('dumpsys', 'connectivity')
                defaults = [line.strip() for line in connectivity.splitlines() if 'Active default network:' in line]
                if defaults and any(re.search(r'(none|null|-1)', line, re.I) for line in defaults):
                    break
            record['networkObservation'] = defaults
            assert defaults and any(re.search(r'(none|null|-1)', line, re.I) for line in defaults), 'An active network remains'
        media_directory = '/sdcard/' + device.media_folder
        assert not device.shell('ls', '-d', media_directory, check=False), 'QA media folder already exists'
        device.shell('mkdir', '-p', media_directory)
        for identifier in used:
            source_path = media_directory + identifier + '.png'
            device.call('push', str(fixtures[identifier]['path']), source_path)
            assert device.shell('sha256sum', source_path).split()[0] == fixture_digest(fixtures[identifier]), 'Fixture transfer changed bytes'
            response = device.shell('content', 'insert', '--uri', 'content://media/external/images/media',
                '--bind', '_data:s:' + source_path, '--bind', '_display_name:s:' + identifier + '.png', '--bind', 'mime_type:s:image/png',
                '--bind', 'relative_path:s:' + device.media_folder, include_stderr=True)
            match = re.search(r'content://media/(?:external|external_primary)/images/media/[0-9]+', response)
            if match:
                uri = match.group(0)
            else:
                # Samsung's content CLI does not print the insert result. Look
                # up only this run's unique folder and exact synthetic filename.
                where = "\"relative_path='" + device.media_folder + "' AND _display_name='" + identifier + ".png'\""
                row = device.shell('content', 'query', '--uri', 'content://media/external/images/media',
                                   '--projection', '_id', '--where', where, include_stderr=True)
                identifiers = re.findall(r'_id=([0-9]+)', row)
                assert len(identifiers) == 1, 'MediaStore did not create the expected temporary QA image'
                uri = 'content://media/external/images/media/' + identifiers[0]
            media_uris[identifier] = uri
        device.shell('input', 'keyevent', 'KEYCODE_WAKEUP')
        for pair in pairs:
            for phase, identifier in zip(['cold', 'warm'], pair):
                fixture = fixtures[identifier]
                if phase == 'cold':
                    device.shell('am', 'force-stop', PACKAGE)
                uri = media_uris[identifier]
                started = time.monotonic()
                device.shell('am', 'start', '-n', PACKAGE + '/com.dalifin.qr.MainActivity', '-a', 'android.intent.action.SEND',
                             '-t', 'image/png', '-d', uri, '--eu', 'android.intent.extra.STREAM', uri, '-f', '0x10000001')
                expected = fixture.get('expectedNativeResults', {}).get('android', [dict(format=fixture.get('format'), value=fixture.get('value'))])
                header = device.wait(lambda nodes: device.contains(nodes, 'Shared image') and
                                     any(device.contains(nodes, LABELS[item['format']]) for item in expected))
                visible_formats = {item['format'] for item in expected if device.contains(header, LABELS[item['format']])}
                # The warm fixture has a different exact value, proving this is
                # a newly consumed intent rather than the previous result.
                device.tap('Details')
                nodes = device.wait(lambda nodes: any(item['value'] in value for item in expected for value in device.strings(nodes)))
                # Details can scroll the header off a smaller phone viewport.
                # Retain the format observed above and verify the new exact text.
                actual = next(item for item in expected if item['format'] in visible_formats and any(item['value'] in value for value in device.strings(nodes)))
                device.confirm_action('Copy contents', 'Contents copied.')
                # Scroll back to the explicit local-save action.
                for _ in range(5):
                    if any('Save to Saved' in value for value in device.strings(device.nodes())):
                        break
                    device.scroll(device.last_nodes, forward=False)
                device.confirm_action('Save to Saved', 'Saved on this device.')
                leftovers = device.shell('run-as', PACKAGE, 'find', 'cache', '-maxdepth', '1', '-name', 'dali_shared_code_*')
                assert not leftovers, 'An owned incoming share copy was not cleaned up'
                outcome = dict(fixture=identifier, phase=phase, source='sharedImage', elapsedMs=round((time.monotonic()-started)*1000),
                               format=actual['format'], value=actual['value'], copied=True, saved=True, cacheClean=True)
                outcomes.append(outcome)
                print('PASS ' + identifier + ' ' + phase, flush=True)
        permission_dump = device.shell('dumpsys', 'package', PACKAGE)
        record['cameraPermissionGranted'] = bool(re.search(r'android\.permission\.CAMERA:\s+granted=true', permission_dump))
        assert not record['cameraPermissionGranted'], 'Image-only sharing must not require camera permission'
        record['result'] = 'passed'
    except BaseException as error:
        record['result'] = 'failed'
        record['error'] = str(error)
        record['lastQaLabels'] = device.strings(device.last_nodes)
        raise
    finally:
        # Remove only item URIs returned by this run's insert operations, before
        # restoring connectivity. Never query or delete the user's media library.
        removed = 0
        for uri in media_uris.values():
            removed += 'Deleted 1 rows' in device.shell('content', 'delete', '--uri', uri, check=False, include_stderr=True)
        where = "\"relative_path='" + device.media_folder + "'\""
        remaining = device.shell('content', 'query', '--uri', 'content://media/external/images/media',
                                 '--projection', '_id:_display_name', '--where', where, include_stderr=True)
        # Also clean a row inserted just before an interrupted URI lookup.
        for line in remaining.splitlines():
            match = re.search(r'_id=([0-9]+), _display_name=([^,]+)', line)
            if match and match.group(2) in [identifier + '.png' for identifier in used]:
                device.shell('content', 'delete', '--uri', 'content://media/external/images/media/' + match.group(1),
                             check=False, include_stderr=True)
        remaining = device.shell('content', 'query', '--uri', 'content://media/external/images/media',
                                 '--projection', '_id', '--where', where, include_stderr=True)
        record['temporaryMedia'] = dict(created=len(media_uris), cleanupVerified='_id=' not in remaining)
        for identifier in used:
            device.shell('rm', '/sdcard/' + device.media_folder + identifier + '.png', check=False)
        device.shell('rmdir', '/sdcard/' + device.media_folder, check=False)
        if args.offline:
            device.shell('cmd', 'connectivity', 'airplane-mode', 'enable' if old_airplane == '1' else 'disable', check=False)
            device.shell('svc', 'wifi', 'enable' if old_wifi in ['1', '2'] else 'disable', check=False)
        device.shell('rm', device.remote + '/view.xml', check=False)
        device.shell('rmdir', device.remote, check=False)
        if installed and not args.keep_installed:
            device.call('uninstall', PACKAGE, check=False)
        record['connectivityRestored'] = dict(airplane=device.shell('settings', 'get', 'global', 'airplane_mode_on'),
                                             wifi=device.shell('settings', 'get', 'global', 'wifi_on'))
        record['qaAppRemoved'] = not bool(device.shell('pm', 'path', PACKAGE, check=False))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
