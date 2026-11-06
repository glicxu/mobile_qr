# Integration-test cleanup incident

Date: 2026-10-29. Affects the development/test package, not the production
package ID. Discovered during the protocol-expansion QA work.

## Observation and impact

The tablet's normal `com.dalifin.qr.test` installation was absent after native
integration checks. Package Manager logs recorded removal of that package.
The phone still had the normal test package and its app-data directories.
The production phone package `com.dalifin.qr` remained installed.
Phone Package Manager logs also contained secondary-user cleanup errors;
presence of the current installation does not prove every earlier data row
or secondary-user copy was preserved.

The tablet test app has been reinstalled. Its previous local History, Saved,
settings and other app data may have been removed by uninstallation; their
recovery is not established. No matching device-data backup was found in the
workspace's `.dart_tool` or `artifacts` directories. This is not a claim about
whether the user has a separate platform backup. No private payloads were
copied into this incident record.

## Cause

The QA APK correctly used the disposable `com.dalifin.qr.scannerqa` ID. However,
Flutter's integration runner obtains and caches APK metadata before rebuilding
the integration listener. When the existing `app-debug.apk` is the normal
test build, that cached identity can remain `com.dalifin.qr.test` for cleanup,
even though device startup refreshes metadata and runs the QA APK.

Flutter test enables integration-app uninstallation by default. Its cleanup
uses the cached application package. A conditional Dart-define application-ID
suffix alone therefore did not protect the normal test installation.

This was a QA setup error. Historical functional decoding/handoff observations
remain usable, but the earlier runs do not establish preservation of normal
test-app data. The issue was disclosed to the user when discovered.

## Correction

- Both QA runners pass `--no-uninstall`; Flutter must not perform cleanup.
- A shared helper first builds the QA APK, then checks its actual package ID
  with `aapt` before the integration runner can cache metadata. This also
  restricts installation fallback and stop operations to the QA identity.
- Unknown existing QA installations are still refused. The runners explicitly
  uninstall only their own `com.dalifin.qr.scannerqa` installation.
- Protected normal/production package presence is checked before and after
  each run. A missing protected installation fails the report and command.
- Native QA must run sequentially, and ordinary debug APKs are rebuilt after
  QA to restore the user-facing build artifact.

Follow-up protection checks and final installed-artifact verification are
recorded in [protocol validation](evidence/protocol-expansion-validation.json).
The corrected runner passed on both devices with the expected QA identity,
the QA package removed, and normal/production package-presence flags unchanged.
Package-presence checks prevent/reveal installation removal; they do not prove
that every pre-existing database row survived the earlier incident.
