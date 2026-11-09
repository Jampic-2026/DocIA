const fs = require("node:fs");
const path = require("node:path");
function writeGallery(root) {
  const report = JSON.parse(
    fs.readFileSync(path.join(root, "docs/VISUAL-REPORT.json"), "utf8"),
  );
  for (const item of report.cases)
    for (const file of [item.baseline, item.monorepo])
      if (!/^[a-zA-Z0-9_.-]+\.png$/.test(file))
        throw Error("Nombre de captura inválido.");
  const directory = path.join(root, ".validation/results");
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(
    path.join(directory, "index.html"),
    `<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Verificación visual de DocIA</title>
<style>body{margin:0;font:15px system-ui;background:#eef2f6;color:#172331}header{padding:20px;background:white;position:sticky;top:0;z-index:1;border-bottom:1px solid #ccd4df}h1{font-size:22px;margin:0 0 8px}select{padding:10px;max-width:100%;font:inherit}main{display:grid;grid-template-columns:1fr 1fr;gap:16px;padding:16px}section{min-width:0}h2{font-size:17px}img{max-width:100%;height:auto;display:block;border:1px solid #cbd5e1}p{margin:8px 0}</style>
<header><h1>DocIA: versión original y monorepo</h1><p>Capturas locales con datos simulados. Los originales y el VPS se conservaron.</p><select id="cases" aria-label="Escenario"></select><p id="status"></p></header>
<main><section><h2>Commit original</h2><a id="before-link" target="_blank"><img id="before" alt="Versión original"></a></section><section><h2>Monorepo</h2><a id="after-link" target="_blank"><img id="after" alt="Versión del monorepo"></a></section></main>
<script>const cases=${JSON.stringify(report.cases)};const select=document.getElementById('cases');for(const [i,item]of cases.entries()){const option=document.createElement('option');option.value=i;option.textContent=item.id;select.append(option);}function show(){const item=cases[Number(select.value)||0];for(const[id,file]of [['before',item.baseline],['after',item.monorepo]]){document.getElementById(id).src=file;document.getElementById(id+'-link').href=file;}document.getElementById('status').textContent=item.changedPixels+' píxeles diferentes · '+item.width+' × '+item.height+' · Click en una imagen para tamaño completo.';}select.addEventListener('change',show);show();</script></html>`,
  );
  console.log("Galería local preparada en .validation/results/index.html.");
}
module.exports = { writeGallery };
if (require.main === module) writeGallery(path.resolve(__dirname, ".."));
