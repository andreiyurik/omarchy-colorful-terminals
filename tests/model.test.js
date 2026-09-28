// Model.js is a QML JavaScript library; load it into a plain node context.
const fs = require("fs")
const vm = require("vm")
const path = require("path")
const M = {}
vm.createContext(M)
vm.runInContext(fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(".pragma library", ""), M)

let passes = 0, failures = 0
function eq(name, expected, actual) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected)
  if (a === e) passes++
  else { failures++; console.log(`  FAIL: ${name}\n        expected: ${e}\n        actual:   ${a}`) }
}

// The palette the helper ships (bin/colorful-terminals).
const helper = fs.readFileSync(path.join(__dirname, "..", "bin", "colorful-terminals"), "utf8")
const names = helper.match(/^palette_names=\((.*)\)$/m)[1].split(" ")
const colors = helper.match(/^palette_colors=\((.*)\)$/m)[1].split(" ").map(s => s.replace(/"/g, ""))
const palette = names.map((name, i) => ({ name, color: colors[i] }))
const lightNames = helper.match(/^light_names=\((.*)\)$/m)[1].split(" ")
const lightColors = helper.match(/^light_colors=\((.*)\)$/m)[1].split(" ").map(s => s.replace(/"/g, ""))
const lightPalette = lightNames.map((name, i) => ({ name, color: lightColors[i] }))

console.log("model: colors")
eq("hex normalizes", "#1a3a5a", M.hexOf("1A3A5A"))
eq("qt color with alpha", "#1a3a5a", M.hexOf("#ff1a3a5a"))
eq("bad hex", "", M.hexOf("#12"))
eq("black on white is 21:1", 21, Math.round(M.contrast("#000000", "#ffffff")))
eq("light theme detected", true, M.isLightTheme("#eff1f5"))
eq("dark theme", false, M.isLightTheme("#2e3440"))
eq("low contrast flagged", "Text is hard to read on this color", M.colorIssue("#9aa0a6", "#d8dee9", "#2e3440"))
eq("same as theme flagged", "Looks the same as your theme", M.colorIssue("#2e3441", "#d8dee9", "#2e3440"))
eq("good color passes", "", M.colorIssue("#1a3a5a", "#d8dee9", "#2e3440"))

// Every palette color must read well on every dark Omarchy theme we can find.
const themeDir = "/usr/share/omarchy/themes"
if (fs.existsSync(themeDir)) {
  let checked = 0, checkedLight = 0
  for (const theme of fs.readdirSync(themeDir)) {
    const file = path.join(themeDir, theme, "colors.toml")
    if (!fs.existsSync(file)) continue
    const toml = fs.readFileSync(file, "utf8")
    const pick = key => (toml.match(new RegExp(`^${key}\\s*=\\s*"(#[0-9a-fA-F]{6})"`, "m")) || [])[1]
    const fg = pick("foreground"), bg = pick("background")
    if (!fg || !bg) continue
    const light = M.isLightTheme(bg)
    light ? checkedLight++ : checked++
    for (const p of light ? lightPalette : palette) eq(`${p.name} on ${theme}`, "", M.colorIssue(p.color, fg, bg))
  }
  eq("checked some dark themes", true, checked > 5)
  eq("checked some light themes", true, checkedLight > 2)
}

console.log("model: palette")
eq("eight colors", 8, palette.length)
// Swatches must be told apart at a glance: no two closer than 6% of the RGB cube.
let closest = 1
for (let i = 0; i < palette.length; i++)
  for (let j = i + 1; j < palette.length; j++) closest = Math.min(closest, M.distance(palette[i].color, palette[j].color))
eq("palette colors are far apart", true, closest > 0.06)
eq("eight light colors", 8, lightPalette.length)
closest = 1
for (let i = 0; i < lightPalette.length; i++)
  for (let j = i + 1; j < lightPalette.length; j++) closest = Math.min(closest, M.distance(lightPalette[i].color, lightPalette[j].color))
eq("light colors are far apart too", true, closest > 0.06)
const projects = [{ n: 1, path: "~/a", color: "#1a3a5a" }]
eq("free color skips used", "#213f12", M.freeColor(palette, projects, "#d8dee9", "#2e3440"))
eq("free color skips poor ones", "#213f12", M.freeColor([{ name: "x", color: "#2e3440" }].concat(palette), projects, "#d8dee9", "#2e3440"))
eq("step right", "#213f12", M.stepColor(palette, "#1a3a5a", 1))
eq("step left wraps", palette[palette.length - 1].color, M.stepColor(palette, "#1a3a5a", -1))
eq("custom steps onto palette", "#1a3a5a", M.stepColor(palette, "#abcdef", 1))
eq("color name", "Blue", M.colorName(palette, "#1A3A5A"))
eq("custom color name", "#abcdef", M.colorName(palette, "#abcdef"))

console.log("model: text and suggestions")
eq("markup stripped", "b onclick=x", M.plain("<b onclick=x>"))
eq("bidi stripped", "abc", M.plain("a‮b\u0007c"))
eq("long text capped", 10, M.plain("x".repeat(50), 10).length)
eq("key label", "Super+Ctrl+Alt+3", M.keyLabel(3))
eq("no key after 9", "No key", M.keyLabel(10))
const s = M.suggestions("", "~/cur", ["~/a", "~/cur", "~/b"], [], projects)
eq("current folder first, no duplicates", ["~/cur", "~/a", "~/b"], s.map(r => r.path))
eq("current folder marked", ["current folder", "", ""], s.map(r => r.note))
eq("a typed folder shows in full", ["~/co", "", "this folder"], [0].map(() => M.suggestions("~/co", "", [], [], [])[0]).map(r => [r.name, r.parent, r.note])[0])
eq("taken marked", 1, s[1].taken)
eq("row name and parent", ["cur", "~"], [s[0].name, s[0].parent])
eq("typed path then subfolders", ["~/co", "~/code"], M.suggestions("~/co/", "", [], ["~/code"], []).map(r => r.path))
eq("search repos", ["~/code/shop"], M.suggestions("SHO", "", ["~/code/shop", "~/b"], [], []).map(r => r.path))

console.log("model: russian layout")
eq("letters by key position", "shop", M.latinKeys("ырщз"))
eq("capitals too", "Shop", M.latinKeys("Ырщз"))
eq("~/ typed on the russian layout", "~/co", M.latinKeys("Ё.сщ"))
eq("latin text untouched", "~/Code.d", M.latinKeys("~/Code.d"))
eq("path query from russian keys", "~/co", M.folderQuery("Ё.сщ"))
eq("cyrillic folder names stay", "~/Проекты", M.folderQuery("~/Проекты"))
eq("search on the russian layout", ["~/code/shop"], M.suggestions("ырщ", "", ["~/code/shop", "~/b"], [], []).map(r => r.path))
eq("russian path gets subfolders", ["~/co", "~/code"], M.suggestions("Ё.сщ", "", [], ["~/code"], []).map(r => r.path))

console.log("model: labels and hints")
eq("name of", "shop", M.nameOf("~/code/shop/"))
eq("parent of", "~/code", M.parentOf("~/code/shop"))
eq("parent of home project", "~", M.parentOf("~/shop"))
eq("parent of root folder", "/", M.parentOf("/srv"))
eq("summary", "4 projects · Super+Ctrl+Alt+1–4", M.summary(4))
eq("summary for one", "1 project · Super+Ctrl+Alt+1", M.summary(1))
eq("summary caps keys at 9", "12 projects · Super+Ctrl+Alt+1–9", M.summary(12))
eq("empty summary", "A color for every project", M.summary(0))
const keysOf = ctx => M.hints(ctx).map(h => h[0])
eq("project hints are short", ["←→", "Enter", "A"], keysOf({ mode: "list", target: "project" }))
eq("missing folder hint", ["Del", "A"], keysOf({ mode: "list", target: "project", missing: true }))
eq("undo is a button, not a hint", ["←→", "Enter", "A"], keysOf({ mode: "list", target: "project", undo: true }))
eq("setup hint", ["Enter", "A"], keysOf({ mode: "list", target: "install" }))
eq("add hints", ["↑↓", "Tab", "Enter", "Esc"], keysOf({ mode: "add" }))
eq("never more than four", true, [{ mode: "list", target: "project", undo: true }, { mode: "add" }, { mode: "hex" }].every(c => M.hints(c).length <= 4))
eq("conflicts only on used keys", [1], M.conflictsFor([{ digit: 1 }, { digit: 5 }], 3).map(c => c.digit))
eq("color key hints", ["←→", "Shift+←→", "C"], keysOf({ mode: "list", target: "paint" }))
eq("color keys always count, 0 too", [0, 8], M.conflictsFor([{ digit: 0, shift: true }, { digit: 8, shift: true }, { digit: 9, shift: true }], 0).map(c => c.digit))
eq("project 0 is the panel, not a project", [], M.conflictsFor([{ digit: 0 }], 3).map(c => c.digit))
eq("digit range", "1–3", M.digitRange([3, 1, 2]))
eq("digit list", "1, 4", M.digitRange([4, 1]))
eq("two in a row", "1–2", M.digitRange([2, 1]))

console.log(`  ${passes} passed, ${failures} failed`)
process.exit(failures ? 1 : 0)
