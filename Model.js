.pragma library

// Pure helpers for the settings panel. No Qt objects, so tests can run them
// in node (see tests/model.test.js).

var MAX_KEYS = 9

function hexOf(value) {
  var s = String(value || "").trim().toLowerCase()
  var m = s.match(/^#?([0-9a-f]{6})$/) || s.match(/^#[0-9a-f]{2}([0-9a-f]{6})$/)
  return m ? "#" + m[1] : ""
}

function rgb(hex) {
  var h = hexOf(hex)
  if (!h) return null
  return {
    r: parseInt(h.substr(1, 2), 16) / 255,
    g: parseInt(h.substr(3, 2), 16) / 255,
    b: parseInt(h.substr(5, 2), 16) / 255
  }
}

function channel(c) {
  return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

function luminance(hex) {
  var c = rgb(hex)
  if (!c) return 0
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
}

// WCAG contrast ratio, 1 to 21.
function contrast(a, b) {
  var la = luminance(a), lb = luminance(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

function distance(a, b) {
  var x = rgb(a), y = rgb(b)
  if (!x || !y) return 1
  return Math.sqrt(Math.pow(x.r - y.r, 2) + Math.pow(x.g - y.g, 2) + Math.pow(x.b - y.b, 2)) / Math.sqrt(3)
}

function isLightTheme(themeBackground) {
  return luminance(themeBackground) > 0.35
}

// Why a background color would be a poor choice on this theme, or "".
function colorIssue(color, themeText, themeBackground) {
  if (!hexOf(color)) return ""
  if (contrast(color, themeText) < 4.5) return "Text is hard to read on this color"
  if (distance(color, themeBackground) < 0.045) return "Looks the same as your theme"
  return ""
}

function usedColors(projects) {
  var used = {}
  for (var i = 0; i < (projects || []).length; i++) used[hexOf(projects[i].color)] = true
  return used
}

// First palette color that no project uses and that reads well on the theme.
function freeColor(palette, projects, themeText, themeBackground) {
  var used = usedColors(projects)
  var i
  for (i = 0; i < palette.length; i++) {
    var c = hexOf(palette[i].color)
    if (!used[c] && !colorIssue(c, themeText, themeBackground)) return c
  }
  for (i = 0; i < palette.length; i++) {
    if (!used[hexOf(palette[i].color)]) return hexOf(palette[i].color)
  }
  return palette.length ? hexOf(palette[(projects || []).length % palette.length].color) : "#243453"
}

function paletteIndex(palette, color) {
  var c = hexOf(color)
  for (var i = 0; i < palette.length; i++) if (hexOf(palette[i].color) === c) return i
  return -1
}

function colorName(palette, color) {
  var i = paletteIndex(palette, color)
  return i >= 0 ? palette[i].name : hexOf(color)
}

// Next palette color left (-1) or right (+1); a custom color steps onto the palette.
function stepColor(palette, color, step) {
  if (!palette.length) return hexOf(color)
  var i = paletteIndex(palette, color)
  if (i < 0) return hexOf(palette[step > 0 ? 0 : palette.length - 1].color)
  return hexOf(palette[(i + step + palette.length) % palette.length].color)
}

function keyLabel(n) {
  return n >= 1 && n <= MAX_KEYS ? "Super+Alt+" + n : "No key"
}

// "4 projects · Super+Alt+1–4" for the panel header.
function summary(count) {
  if (!count) return "A color for every project"
  var keys = Math.min(count, MAX_KEYS)
  return count + (count === 1 ? " project" : " projects") + " · Super+Alt+" + (keys === 1 ? "1" : "1–" + keys)
}

// The few key hints worth showing for what is on screen. ctx: {mode, target,
// missing}. Everything else lives in tooltips and buttons (Undo, Turn off).
function hints(ctx) {
  var c = ctx || {}
  if (c.mode === "hex") return [["Enter", "apply"], ["Esc", "cancel"]]
  if (c.mode === "add") return [["↑↓", "choose"], ["Tab", "complete"], ["Enter", "add"], ["Esc", c.empty ? "close" : "back"]]
  var out = []
  if (c.target === "project") {
    if (c.missing) out.push(["Del", "remove"])
    else out.push(["←→", "color"], ["Enter", "open"])
  } else if (c.target === "keys") {
    out.push(["Space", "switch"])
  } else if (c.target === "install") {
    out.push(["Enter", "turn on"])
  }
  out.push(["A", "add"])
  return out
}

// Text safe to hand to components we do not control: no markup characters,
// control characters, or bidi overrides, and not too long.
function plain(text, max) {
  var s = String(text === undefined || text === null ? "" : text)
    .replace(/[\u0000-\u001f\u007f-\u009f‎‏‪-‮⁦-⁩<>&]/g, "")
  var limit = max || 200
  return s.length > limit ? s.substr(0, limit - 1) + "…" : s
}

function isPathQuery(text) {
  var t = String(text || "")
  return t === "~" || t.indexOf("~/") === 0 || t.indexOf("/") === 0
}

function projectNumber(projects, path) {
  for (var i = 0; i < (projects || []).length; i++) if (projects[i].path === path) return projects[i].n
  return 0
}

// Folder name and the folder it sits in: "~/code/shop" -> "shop", "~/code".
function nameOf(path) {
  var p = String(path || "").replace(/\/+$/, "")
  if (p === "" || p === "~") return p || "/"
  var i = p.lastIndexOf("/")
  return i >= 0 ? p.substr(i + 1) : p
}

function parentOf(path) {
  var p = String(path || "").replace(/\/+$/, "")
  var i = p.lastIndexOf("/")
  if (i < 0) return ""
  return i === 0 ? "/" : p.substr(0, i)
}

// Text typed on a Russian layout, read as the Latin keys under the same
// fingers: "Ё." is "~/" and "ырщз" is "shop". Other text is returned as is.
var RU = "йцукенгшщзхъфывапролджэячсмитьбюё"
var US = "qwertyuiop[]asdfghjkl;'zxcvbnm,.`"
var RU_SHIFTED = { "Ё": "~", ".": "/", ",": "?", "\"": "@", "№": "#", ";": "$", ":": "^", "?": "&" }
function latinKeys(text) {
  var s = String(text || "")
  if (!/[а-яё]/i.test(s)) return s
  var out = ""
  for (var i = 0; i < s.length; i++) {
    var c = s.charAt(i)
    var lower = c.toLowerCase()
    var at = RU.indexOf(lower)
    if (RU_SHIFTED[c] !== undefined) out += RU_SHIFTED[c]
    else if (at >= 0) out += lower === c ? US.charAt(at) : US.charAt(at).toUpperCase()
    else out += c
  }
  return out
}

// What the folder field means: a path as typed, a path typed on the Russian
// layout ("Ё.co" -> "~/co"), or search text.
function folderQuery(text) {
  var t = String(text || "").trim()
  if (isPathQuery(t)) return t
  var latin = latinKeys(t)
  return isPathQuery(latin) ? latin : t
}

// Rows for the "Add project" list. Each row: {path, label, detail, taken}.
//   empty query  current folder, then git repositories
//   ~/ or /…     the typed folder, then its subfolders (from the helper)
//   other text   repositories whose path contains the text (either layout)
function suggestions(query, currentDir, repos, dirs, projects) {
  var rows = []
  var seen = {}
  function add(path, label, detail) {
    if (!path || seen[path]) return
    seen[path] = true
    rows.push({ path: path, label: label, detail: detail, taken: projectNumber(projects, path) })
  }
  var q = folderQuery(query)
  var i
  if (!q) {
    if (currentDir) add(currentDir, "Add current folder", currentDir)
    for (i = 0; i < (repos || []).length; i++) add(repos[i], repos[i], "git repository")
  } else if (isPathQuery(q)) {
    var typed = q.length > 1 ? q.replace(/\/+$/, "") : q
    add(typed, typed, "this folder")
    for (i = 0; i < (dirs || []).length; i++) add(dirs[i], dirs[i], "")
  } else {
    var needle = q.toLowerCase()
    var latin = latinKeys(q).toLowerCase()
    for (i = 0; i < (repos || []).length; i++) {
      var r = repos[i].toLowerCase()
      if (r.indexOf(needle) >= 0 || r.indexOf(latin) >= 0) add(repos[i], repos[i], "git repository")
    }
  }
  return rows
}

// Digits in use by projects that another binding also claims.
function conflictsFor(conflicts, projectCount) {
  var out = []
  var limit = Math.min(projectCount, MAX_KEYS)
  for (var i = 0; i < (conflicts || []).length; i++) {
    var c = conflicts[i]
    if (c.digit >= 1 && c.digit <= limit) out.push(c)
  }
  return out
}

// "1–3" style label for a list of digits.
function digitRange(digits) {
  var d = digits.slice().sort(function(a, b) { return a - b })
  var unique = []
  for (var i = 0; i < d.length; i++) if (unique.indexOf(d[i]) < 0) unique.push(d[i])
  if (!unique.length) return ""
  var contiguous = unique[unique.length - 1] - unique[0] === unique.length - 1
  if (unique.length > 1 && contiguous) return unique[0] + "–" + unique[unique.length - 1]
  return unique.join(", ")
}
