// Rewrites the Adwaita-for-Steam bundles without CSS nesting or :is().
// Steam's CEF (Chrome 126) can't bucket rules whose rightmost part is :is(...), so it
// tests them against every element; expanding them made a restyle ~7x faster (134 -> 17 ms).
// No minify: it drops the space in 'var(--a) var(--b)', which breaks color-mix() hover/click highlights.
// Re-run after every theme install/update: node ~/.local/share/steam-adwaita-flatten/flatten.js
const { transform, Features } = require('lightningcss'), fs = require('fs'), path = require('path');
// Chrome 80 target makes lightningcss expand nesting into plain selectors; exclude every other downlevel rewrite.
const keep = Features.Nesting | Features.IsSelector, all = Object.values(Features).reduce((a, b) => a | b, 0);
const dir = path.join(process.env.HOME, '.local/share/Steam/steamui/adwaita');
for (const f of ['base.min.css', 'main.min.css']) {
  const p = path.join(dir, f), src = fs.readFileSync(p, 'utf8');
  // Hide light-dark() from lightningcss: it downlevels it into --lightningcss-* vars that Steam never sets.
  const hidden = src.replaceAll('light-dark(', 'zzlightdark(');
  if (src.startsWith('/* flattened */')) { console.log(f, 'already flattened'); continue; }
  fs.writeFileSync(p + '.orig', src);
  const { code } = transform({ filename: f, code: Buffer.from(hidden), errorRecovery: true,
    targets: { chrome: 80 << 16 }, include: keep, exclude: all & ~keep });
  fs.writeFileSync(p, '/* flattened */' + code.toString().replaceAll('zzlightdark(', 'light-dark('));
  console.log(f, src.length, '->', code.length);
}
