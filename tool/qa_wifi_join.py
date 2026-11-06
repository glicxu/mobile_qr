"""Run isolated Android Wi-Fi tests; observe approval screens and cancel them.

Never approves a network, reads real saved credentials, or clears normal app data.
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
from android_qa_safety import protected_presence, prepare_qa_identity

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = 'com.dalifin.qr.scannerqa'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--serial', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
prefix = ['adb', '-s', args.serial]
run_id = uuid.uuid4().hex[:8]
remote = '/data/local/tmp/dali_wifi_qa_' + run_id + '.xml'
log_path = ROOT / '.dart_tool' / ('wifi-native-' + args.serial + '.log')

def adb(*cmd, check=True, timeout=25):
    r = subprocess.run(prefix + list(cmd), capture_output=True, timeout=timeout)
    if check:
        r.check_returncode()
    return r.stdout.decode('utf-8', errors='replace').strip()

assert not adb('shell', 'pm', 'path', PACKAGE, check=False), 'Refusing to overwrite an existing QA app'
old_wifi = adb('shell', 'settings', 'get', 'global', 'wifi_on')
assert old_wifi in ['0', '1', '2', '3']
record = dict(date='2026-10-29', device=args.serial, package=PACKAGE, runId=run_id, scope='Production Wi-Fi review, native configuration validation, OS approval screen, duplicate guard and cancellation. No network approved.', systemScreens=[], originalWifiState=old_wifi)
process = None
record['protectedPackagesBefore'] = protected_presence(args.serial)
try:
    record['initialFlutterApkIdentity'] = prepare_qa_identity(ROOT, args.serial)
    with log_path.open('wb') as log:
        process = subprocess.Popen([os.environ.get('COMSPEC', 'cmd.exe'), '/d', '/c', 'C:\\dev\\flutter\\bin\\flutter.bat',
            'test', 'integration_test/wifi_join_test.dart', '-d', args.serial,
            '--no-uninstall', '--dart-define=DALI_SCANNER_QA_BUILD=true', '--dart-define=WIFI_QA_ID=' + run_id], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 420
        seen = set()
        while process.poll() is None and time.monotonic() < deadline:
            activity = adb('shell', 'dumpsys', 'activity', 'activities')
            resumed = [line for line in activity.splitlines() if 'mResumedActivity:' in line]
            if not any('settings' in line.lower() for line in resumed):
                time.sleep(.5)
                continue
            try:
                adb('shell', 'uiautomator', 'dump', '--compressed', remote, timeout=20)
                raw = subprocess.check_output(prefix + ['exec-out', 'cat', remote], timeout=10)
                start = raw.find(b'<?xml')
                if start < 0:
                    continue
                root = ET.fromstring(raw[start:])
                labels = [n.get(key, '') for n in root.iter('node') if 'settings' in n.get('package', '').lower() for key in ['text', 'content-desc']]
                for security in ['WPA2', 'OPEN', 'WPA3']:
                    ssid = 'DALI-QR-QA-' + run_id + '-' + security
                    if security not in seen and any(ssid in value for value in labels):
                        seen.add(security)
                        record['systemScreens'].append(dict(security=security.lower(), ssidObserved=True, action='Back; network not accepted'))
                        print('Observed real OS approval: ' + security + '; cancelling.', flush=True)
                        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
                        break
            except (ET.ParseError, subprocess.TimeoutExpired):
                pass
            time.sleep(.5)
        if process.poll() is None:
            raise TimeoutError('Wi-Fi QA exceeded its deadline')
    text = log_path.read_text(encoding='utf-8', errors='replace')
    cases = [json.loads(line.split('WIFI_JOIN_QA ', 1)[1]) for line in text.splitlines() if 'WIFI_JOIN_QA ' in line]
    record['cases'] = cases
    assert 'All tests passed!' in text, 'Native integration failed; inspect the local test log'
    assert len(cases) == 4
    assert {'WPA2', 'OPEN'}.issubset(seen)
    assert all(c['result'] in ['passed', 'cancelled', 'unsupportedOnDevice'] for c in cases)
    artifact = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
    record['testedApkSha256'] = hashlib.sha256(artifact.read_bytes()).hexdigest()
    record['result'] = 'passed'
except BaseException as error:
    record['result'] = 'failed'
    record['error'] = str(error)
    raise
finally:
    if process is not None and process.poll() is None:
        adb('shell', 'am', 'force-stop', PACKAGE, check=False)
        try:
            process.wait(timeout=20)
        except subprocess.TimeoutExpired:
            process.terminate()
    adb('shell', 'rm', remote, check=False)
    if adb('shell', 'pm', 'path', PACKAGE, check=False):
        adb('uninstall', PACKAGE, check=False)
    record['qaAppRemoved'] = not bool(adb('shell', 'pm', 'path', PACKAGE, check=False))
    now_wifi = adb('shell', 'settings', 'get', 'global', 'wifi_on')
    expected_wifi = '1' if old_wifi in ['1', '2'] else '0'
    if now_wifi != expected_wifi:
        adb('shell', 'svc', 'wifi', 'enable' if expected_wifi == '1' else 'disable')
    record['restoredWifiState'] = adb('shell', 'settings', 'get', 'global', 'wifi_on')
    record['protectedPackagesAfter'] = protected_presence(args.serial)
    lost = [package for package, present in record['protectedPackagesBefore'].items()
            if present and not record['protectedPackagesAfter'][package]]
    if lost:
        record['result'] = 'failed'
        record['error'] = 'Protected app installation was removed'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    if lost:
        raise RuntimeError('Protected app installation was removed')
