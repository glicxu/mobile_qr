# Candidate format fixtures

Evaluation-only Data Matrix, PDF417 and Aztec images. See
[WP1 observations and limitations](../../../docs/qa/optional_formats.md).
Production does not enable these formats.

Generator: pinned bwip-js 4.11.4 using the same ignored development installation
as [the scanner fixtures](../barcodes/README.md). Reproduce with
`node tool/generate_optional_format_fixtures.cjs --check`. Independently decode
with `python tool/verify_barcode_fixtures.py --optional`.

The short value deliberately preserves leading/trailing spaces and zeroes.
The short Aztec is valid under independent decoding but currently fails both
recorded Android native probes. Keep it as qualification evidence.
