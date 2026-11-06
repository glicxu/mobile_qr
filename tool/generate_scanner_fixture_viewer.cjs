// An entirely offline optical-camera QA chart, using the committed PNGs.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const fixtures = [];
for (const name of ['barcodes', 'optional_formats']) {
  const directory = path.join(root, 'test/fixtures', name);
  for (const fixture of JSON.parse(fs.readFileSync(path.join(directory, 'manifest.json'), 'utf8')).fixtures) {
    fixtures.push({
      id: fixture.id, format: fixture.symbolFormat || fixture.format,
      value: fixture.encodedValue ?? fixture.value,
      expected: fixture.expectedNativeResults?.android || [{ format: fixture.format, value: fixture.value }],
      data: 'data:image/png;base64,' + fs.readFileSync(path.join(directory, fixture.file || fixture.id + '.png')).toString('base64'),
    });
  }
}
const html = `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dali QR — offline camera test chart</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#fff;color:#17243a;font:16px system-ui,sans-serif}
header,footer{padding:14px 24px;background:#eef2f8}header{display:flex;gap:12px;align-items:center;flex-wrap:wrap}
button,select{font:inherit;padding:9px;border:1px solid #9baac1;border-radius:6px;background:white;color:inherit}
main{min-height:65vh;display:grid;place-items:center;padding:28px;overflow:auto}img{image-rendering:pixelated;max-width:95vw;height:auto}
pre{white-space:pre-wrap;overflow-wrap:anywhere}label{display:flex;gap:8px;align-items:center}h1{font-size:18px;margin:0}
</style>
<header><h1>Dali QR · optical scanner QA</h1><button id="previous">Previous</button><select id="fixture" aria-label="Barcode fixture"></select>
<button id="next">Next</button><label>Scale <select id="scale"><option>1</option><option>2</option><option>3</option></select></label>
<button id="fullscreen">Full screen</button></header>
<main><img id="code" alt="Synthetic barcode test fixture"></main>
<footer><strong id="name"></strong><pre id="value"></pre><p>Center this single code in the tablet camera. Choose image scans an existing image; the scanner does not open the camera app to take photos.
Check the format, exact value, copy, Save to Saved, Scan again, and cancellation. These are synthetic test values; this page makes no network requests.</p>
<pre id="expected"></pre></footer>
<script>
const fixtures=${JSON.stringify(fixtures).replace(/</g, '\\u003c')};
let index=0;const select=document.getElementById('fixture'),scale=document.getElementById('scale'),image=document.getElementById('code');
fixtures.forEach((f,i)=>{const option=document.createElement('option');option.value=i;option.textContent=f.id+' · '+f.format;select.append(option)});
function show(){const f=fixtures[index];select.value=index;image.src=f.data;image.onload=()=>{image.style.width=(image.naturalWidth*Number(scale.value))+'px'};
document.getElementById('name').textContent=f.id+' · '+(index+1)+' / '+fixtures.length;
document.getElementById('value').textContent='Exact encoded value: '+JSON.stringify(f.value);
document.getElementById('expected').textContent='Allowed Android decoder representations: '+JSON.stringify(f.expected)}
select.onchange=()=>{index=Number(select.value);show()};scale.onchange=show;
document.getElementById('previous').onclick=()=>{index=(index+fixtures.length-1)%fixtures.length;show()};
document.getElementById('next').onclick=()=>{index=(index+1)%fixtures.length;show()};
document.getElementById('fullscreen').onclick=()=>document.documentElement.requestFullscreen().catch(()=>{});show();
</script></html>\n`;
const target = path.join(root, 'docs/qa/scanner_fixture_viewer.html');
if (process.argv.includes('--check')) {
  if (fs.readFileSync(target, 'utf8') !== html) throw new Error('Fixture viewer drift');
} else fs.writeFileSync(target, html);
console.log('Offline camera chart: ' + fixtures.length + ' committed fixtures.');
