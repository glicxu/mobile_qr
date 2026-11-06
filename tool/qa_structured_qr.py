"""Isolated Android QR decoding and confirmed action handoff checks.

Synthetic data only. Observes external activities and brings the QA app back.
Never presses Send, Save, Call, Pay, or authenticator-provider buttons.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from android_qa_safety import protected_presence, prepare_qa_identity

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = 'com.dalifin.qr.scannerqa'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--serial', required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--authenticator-only', action='store_true')
args = parser.parse_args()
prefix = ['adb', '-s', args.serial]
log_path = ROOT / '.dart_tool' / (('authenticator-native-' if args.authenticator_only else 'structured-native-') + args.serial + '.log')


def adb(*cmd, check=True, timeout=25):
    result = subprocess.run(prefix + list(cmd), capture_output=True, timeout=timeout)
    if check:
        result.check_returncode()
    return result.stdout.decode('utf-8', errors='replace').strip()


assert not adb('shell', 'pm', 'path', PACKAGE, check=False), 'Refusing to overwrite existing QA app'
record = dict(date='2026-10-29', device=args.serial, package=PACKAGE,
              model=adb('shell', 'getprop', 'ro.product.model'),
              api=adb('shell', 'getprop', 'ro.build.version.sdk'),
              scope='Synthetic native QR round trips and confirmed action handoffs. No records saved, messages sent, calls placed or authenticator accounts added.',
              handoffs=[])
record['protectedPackagesBefore'] = protected_presence(args.serial)
process = None
try:
    record['initialFlutterApkIdentity'] = prepare_qa_identity(ROOT, args.serial)
    with log_path.open('wb') as log:
        command = [os.environ.get('COMSPEC', 'cmd.exe'), '/d', '/c',
            'C:\\dev\\flutter\\bin\\flutter.bat', 'test', 'integration_test/structured_qr_test.dart',
            '-d', args.serial, '--no-uninstall', '--dart-define=DALI_SCANNER_QA_BUILD=true']
        if args.authenticator_only:
            command += ['--name', 'authenticator review']
            record['scope'] = 'Credential-free authenticator availability query, masked review cancellation, and absent-handler behavior. No authenticator provider launched.'
        process = subprocess.Popen(command,
            cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 600
        seen = set()
        last_return = 0.0
        while process.poll() is None and time.monotonic() < deadline:
            text = log_path.read_text(encoding='utf-8', errors='replace')
            begins = re.findall(r'STRUCTURED_HANDOFF_BEGIN (\{[^\r\n]+\})', text)
            if args.authenticator_only and 'STRUCTURED_QR_QA ' in text:
                # A handler opened by an earlier ordinary route can finish
                # its own asynchronous activity chain after QA regains focus.
                # Keep this no-launch authenticator check on its own surface.
                activity = adb('shell', 'dumpsys', 'activity', 'activities')
                resumed = [s for s in activity.splitlines() if 'mResumedActivity:' in s]
                if resumed and not any(PACKAGE in s for s in resumed) and time.monotonic() - last_return > 2 and adb('shell', 'pm', 'path', PACKAGE, check=False):
                    adb('shell', 'am', 'start', '--activity-reorder-to-front', '-n', PACKAGE + '/com.dalifin.qr.MainActivity')
                    last_return = time.monotonic()
            if begins:
                case = json.loads(begins[-1])['type']
                if case not in seen:
                    activity = adb('shell', 'dumpsys', 'activity', 'activities')
                    resumed = [s for s in activity.splitlines() if 'mResumedActivity:' in s]
                    if resumed and not any(PACKAGE in s for s in resumed):
                        match = re.search(r' u\d+ ([\w.$]+/[\w.$]+)', resumed[0])
                        if match:
                            component = match.group(1)
                            assert case in ['contact', 'event', 'location', 'email', 'phone', 'sms']
                            seen.add(case)
                            record['handoffs'].append(dict(type=case, component=component,
                                action='Observed; QA app reordered to front; no commit buttons pressed'))
                            print('Observed external handoff: ' + case, flush=True)
                            time.sleep(.8)
                            adb('shell', 'am', 'start', '--activity-reorder-to-front',
                                '-n', PACKAGE + '/com.dalifin.qr.MainActivity')
            time.sleep(.3)
        if process.poll() is None:
            raise TimeoutError('Structured QR integration exceeded its deadline')
    text = log_path.read_text(encoding='utf-8', errors='replace')
    cases = [json.loads(s) for s in re.findall(r'STRUCTURED_QR_QA (\{[^\r\n]+\})', text)]
    record['cases'] = cases
    assert 'All tests passed!' in text, 'Inspect local native test log'
    assert len(cases) == (1 if args.authenticator_only else 13)
    for case in cases:
        if case['type'].endswith('_handoff') and case['result'] == 'returned':
            assert case['type'].removesuffix('_handoff') in seen, 'Handoff lacked external-activity evidence'
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
