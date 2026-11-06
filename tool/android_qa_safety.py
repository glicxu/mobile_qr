"""Prevent Flutter integration cleanup from using a stale normal-app identity."""
import os
from pathlib import Path
import re
import subprocess

QA_PACKAGE = 'com.dalifin.qr.scannerqa'
PROTECTED_PACKAGES = ('com.dalifin.qr.test', 'com.dalifin.qr')


def protected_presence(serial):
    result = {}
    for package in PROTECTED_PACKAGES:
        command = subprocess.run(['adb', '-s', serial, 'shell', 'pm', 'list', 'packages', '--user', '0', package],
                                 capture_output=True, timeout=25)
        command.check_returncode()
        result[package] = ('package:' + package) in command.stdout.decode('utf-8').splitlines()
    return result


def prepare_qa_identity(root, serial):
    """Flutter caches APK metadata before compiling the integration listener.

    Prebuild and verify QA metadata so install fallback/stop target QA, and pass
    --no-uninstall in callers so only their explicit QA cleanup can uninstall.
    """
    root = Path(root)
    log = root / '.dart_tool' / ('qa-safety-prebuild-' + serial + '.log')
    with log.open('wb') as output:
        result = subprocess.run([os.environ.get('COMSPEC', 'cmd.exe'), '/d', '/c',
            'C:\\dev\\flutter\\bin\\flutter.bat', 'build', 'apk', '--debug',
            '--dart-define=DALI_SCANNER_QA_BUILD=true'], cwd=root,
            stdout=output, stderr=subprocess.STDOUT, timeout=600)
    result.check_returncode()
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or
               str(Path(os.environ['LOCALAPPDATA']) / 'Android' / 'Sdk'))
    candidates = list((sdk / 'build-tools').glob('*/aapt.exe'))
    assert candidates, 'aapt is required to verify the QA APK identity'
    aapt = max(candidates, key=lambda p: tuple(int(n) for n in re.findall(r'\d+', p.parent.name)))
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    badging = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)]).decode('utf-8')
    match = re.search(r"^package: name='([^']+)'", badging, re.MULTILINE)
    assert match and match.group(1) == QA_PACKAGE, 'Refusing to test using normal/production APK metadata'
    return QA_PACKAGE
