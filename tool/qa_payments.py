"""Run Payments QA only in the verified disposable Android package."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from android_qa_safety import protected_presence, prepare_qa_identity

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = 'com.dalifin.qr.scannerqa'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--serial', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
prefix = ['adb', '-s', args.serial]
log_path = ROOT / '.dart_tool' / ('payments-native-' + args.serial + '.log')


def adb(*cmd, check=True, timeout=25):
    result = subprocess.run(prefix + list(cmd), capture_output=True, timeout=timeout)
    if check:
        result.check_returncode()
    return result.stdout.decode('utf-8', errors='replace').strip()


assert not adb('shell', 'pm', 'path', PACKAGE, check=False), 'Refusing to overwrite existing QA app'
record = dict(date='2026-10-30', device=args.serial, package=PACKAGE,
              model=adb('shell', 'getprop', 'ro.product.model'),
              api=adb('shell', 'getprop', 'ro.build.version.sdk'),
              scope='Synthetic local Payments persistence and native QR/card decoding. Test-only entitlement; no store or checkout calls.')
record['protectedPackagesBefore'] = protected_presence(args.serial)
process = None
try:
    record['initialFlutterApkIdentity'] = prepare_qa_identity(ROOT, args.serial)
    with log_path.open('wb') as log:
        command = [os.environ.get('COMSPEC', 'cmd.exe'), '/d', '/c',
            'C:\\dev\\flutter\\bin\\flutter.bat', 'test', 'integration_test/payments_workspace_test.dart',
            '-d', args.serial, '--no-uninstall', '--dart-define=DALI_SCANNER_QA_BUILD=true']
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        process.wait(timeout=600)
    text = log_path.read_text(encoding='utf-8', errors='replace')
    cases = [json.loads(s) for s in re.findall(r'PAYMENTS_QA (\{[^\r\n]+\})', text)]
    record['cases'] = cases
    assert process.returncode == 0 and 'All tests passed!' in text, 'Inspect local native test log'
    assert len(cases) == 1 and cases[0]['result'] == 'passed'
    preview = ROOT / '.dart_tool' / ('payments-card-' + args.serial + '.png')
    rendered = subprocess.run(prefix + ['exec-out', 'run-as', PACKAGE, 'cat', 'cache/payments_qa_preview.png'], capture_output=True, timeout=25)
    rendered.check_returncode()
    assert rendered.stdout.startswith(b'\x89PNG'), 'Native preview missing'
    preview.write_bytes(rendered.stdout)
    record['nativePreviewSha256'] = hashlib.sha256(rendered.stdout).hexdigest()
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
    if adb('shell', 'pm', 'path', PACKAGE, check=False):
        adb('uninstall', PACKAGE, check=False)
    record['qaAppRemoved'] = not bool(adb('shell', 'pm', 'path', PACKAGE, check=False))
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
