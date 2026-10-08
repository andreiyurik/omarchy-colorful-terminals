// The default palettes against Omarchy's stock themes: every color must read,
// stand off the theme background, and stay apart from the others. A snapshot
// of the 22 themes' background and foreground is kept here so CI needs no
// Omarchy; when /usr/share/omarchy/themes is there, its live colors are used
// too, so a new theme that breaks the palette shows up.
//   node tests/palette.test.js
const fs = require("fs")
const path = require("path")
const repo = path.join(__dirname, "..")
let failures = 0, passes = 0
function ok(name, cond, detail) {
  if (cond) passes++
  else { failures++; console.log("  FAIL: " + name + (detail ? "\n        " + detail : "")) }
}

// The palettes, read from the helper so they cannot drift from it.
const helper = fs.readFileSync(path.join(repo, "bin/colorful-terminals"), "utf8")
function bashArray(name) {
  const m = helper.match(new RegExp("\\n" + name + "=\\(([^)]*)\\)"))
  return m[1].trim().split(/\s+/).map(s => s.replace(/"/g, ""))
}
const dark = bashArray("palette_colors"), darkNames = bashArray("palette_names")
const light = bashArray("light_colors"), lightNames = bashArray("light_names")

// Omarchy 4.0.4 stock themes: name, background, foreground.
const snapshot = [
  ["catppuccin-latte", "#eff1f5", "#4c4f69"],
  ["catppuccin", "#1e1e2e", "#cdd6f4"],
  ["ethereal", "#060b1e", "#ffcead"],
  ["everforest", "#2d353b", "#d3c6aa"],
  ["flexoki-light", "#fffcf0", "#100f0f"],
  ["gruvbox", "#282828", "#d4be98"],
  ["hackerman", "#0b0c16", "#ddf7ff"],
  ["kanagawa", "#1f1f28", "#dcd7ba"],
  ["last-horizon", "#0c0b0c", "#fafcfb"],
  ["lumon", "#16242d", "#d6e2ee"],
  ["lupine", "#fafafa", "#212121"],
  ["matte-black", "#121212", "#bebebe"],
  ["miasma", "#222222", "#c2c2b0"],
  ["nord", "#2e3440", "#d8dee9"],
  ["osaka-jade", "#111c18", "#c1c497"],
  ["retro-82", "#05182e", "#f6dcac"],
  ["ristretto", "#2c2525", "#e6d9db"],
  ["rose-pine", "#faf4ed", "#575279"],
  ["solitude", "#101315", "#cacccc"],
  ["tokyo-night", "#1a1b26", "#a9b1d6"],
  ["vantablack", "#000000", "#ffffff"],
  ["white", "#ffffff", "#000000"]
]
let themes = snapshot.map(([name, bg, fg]) => ({ name, bg, fg, live: false }))
const live = "/usr/share/omarchy/themes"
if (fs.existsSync(live)) {
  for (const name of fs.readdirSync(live)) {
    const file = path.join(live, name, "colors.toml")
    if (!fs.existsSync(file)) continue
    const text = fs.readFileSync(file, "utf8")
    const get = key => (text.match(new RegExp("^\\s*" + key + "\\s*=\\s*\"?(#[0-9a-fA-F]{6})", "m")) || [])[1]
    if (get("background") && get("foreground")) themes.push({ name: name + " (live)", bg: get("background").toLowerCase(), fg: get("foreground").toLowerCase(), live: true })
  }
}

// Color math: WCAG contrast and CIE76 distance in Lab.
function rgb(h) { return [1, 3, 5].map(i => parseInt(h.substr(i, 2), 16) / 255) }
function lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
function lum(h) { const [r, g, b] = rgb(h).map(lin); return 0.2126 * r + 0.7152 * g + 0.0722 * b }
function contrast(a, b) { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05) }
function lab(h) {
  const [r, g, b] = rgb(h).map(lin)
  const x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047, y = r * 0.2126 + g * 0.7152 + b * 0.0722, z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
  const f = t => t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))]
}
function dE(a, b) { const p = lab(a), q = lab(b); return Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]) }
const isLight = t => lum(t.bg) > 0.35

function check(label, colors, names, selected, minPair, minContrast, minBg) {
  console.log("palette: " + label)
  ok(label + " has 8 colors", colors.length === 8 && names.length === 8)
  ok(label + " colors are unique", new Set(colors).size === 8, colors.join(" "))
  ok(label + " names are unique", new Set(names).size === 8)
  ok(label + " colors are lowercase #rrggbb", colors.every(c => /^#[0-9a-f]{6}$/.test(c)))
  let worstPair = 99, pairNames = ""
  for (let i = 0; i < 8; i++) for (let j = i + 1; j < 8; j++) {
    const d = dE(colors[i], colors[j])
    if (d < worstPair) { worstPair = d; pairNames = names[i] + "/" + names[j] }
  }
  ok(label + ": the two closest colors differ by dE " + minPair + " or more", worstPair >= minPair, pairNames + " differ by " + worstPair.toFixed(1))
  for (const t of selected) {
    const worst = colors.map((c, i) => [contrast(c, t.fg), names[i]]).sort((a, b) => a[0] - b[0])[0]
    ok(label + ": text reads on every color on " + t.name, worst[0] >= minContrast, worst[1] + " contrast " + worst[0].toFixed(2))
    // The neutral (black or gray) is the theme background on some themes; the panel marks that.
    const hued = colors.slice(0, 7).map((c, i) => [dE(c, t.bg), names[i]]).sort((a, b) => a[0] - b[0])[0]
    ok(label + ": every hue stands off the background of " + t.name, hued[0] >= minBg, hued[1] + " is dE " + hued[0].toFixed(1) + " from " + t.bg)
  }
}
check("dark", dark, darkNames, themes.filter(t => !isLight(t)), 18, 5.0, 14)
check("light", light, lightNames, themes.filter(isLight), 15, 4.5, 15)

console.log("palette: the keys file")
const keys = fs.readFileSync(path.join(repo, "hypr/keys.lua"), "utf8")
ok("dark names match hypr/keys.lua", keys.includes('M.palette = { "' + darkNames.join('", "') + '" }'))
ok("light names match hypr/keys.lua", keys.includes('M.palette_light = { "' + lightNames.join('", "') + '" }'))
console.log("palette: the README")
const readme = fs.readFileSync(path.join(repo, "README.md"), "utf8")
for (let i = 0; i < 8; i++) {
  ok("README lists " + darkNames[i] + " " + dark[i], readme.includes(darkNames[i] + " | `" + dark[i] + "`"))
  ok("README lists " + lightNames[i] + " " + light[i], readme.includes(lightNames[i] + " | `" + light[i] + "`"))
}

console.log(`  ${passes} passed, ${failures} failed`)
process.exit(failures ? 1 : 0)
