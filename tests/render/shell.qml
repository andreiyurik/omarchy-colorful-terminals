import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Renders the settings panel offscreen in several states and saves PNGs, then
// drives it with fake key presses. Run by tests/render-panel; prints PASS/FAIL.
ShellRoot {
  id: test

  readonly property string outDir: Quickshell.env("CT_RENDER_DIR")

  readonly property var palette: [
    { name: "Blue", color: "#1a3a5a" }, { name: "Green", color: "#213f12" }, { name: "Red", color: "#681e1e" },
    { name: "Violet", color: "#4c2276" }, { name: "Plum", color: "#621d4b" }, { name: "Brown", color: "#4c3316" },
    { name: "Indigo", color: "#262e82" }, { name: "Jade", color: "#13402a" }
  ]
  function project(n, path, color, exists) {
    var name = path.split("/").pop()
    return { n: n, path: path, abs: path, color: color, name: name, exists: exists !== false }
  }
  function config(projects, extra) {
    var c = { projects: projects, palette: palette, problems: [], integration: { installed: true },
              replaceGroupKeys: false, replaceGroupKeysSet: false, file: "~/.config/colorful-terminals/projects.conf" }
    for (var k in extra || {}) c[k] = extra[k]
    return c
  }
  function groupKeys(n) {
    var out = []
    for (var d = 1; d <= n; d++) out.push({ digit: d, description: "Switch to group window " + d, byCode: true })
    return out
  }
  readonly property var fourProjects: [
    project(1, "~/code/shop", "#1a3a5a"), project(2, "~/code/blog", "#213f12"),
    project(3, "~/work/api-gateway", "#681e1e"), project(4, "~/work/api-gateway/admin", "#4c2276")
  ]
  readonly property string previewText: "~/.bashrc  (at the end)\n    # BEGIN colorful-terminals (...)\n    if [[ -r \"$HOME\"/.config/omarchy/plugins/andreiyurik.colorful-terminals/shell/colorful-terminals.bash ]]; then source ...; fi\n    # END colorful-terminals\n\n~/.config/hypr/hyprland.lua  (at the end)\n    -- BEGIN colorful-terminals (...)\n    do local dir = os.getenv(\"HOME\") .. \"/.config/omarchy/plugins/andreiyurik.colorful-terminals\"; ... end\n    -- END colorful-terminals"
  readonly property var noScan: ({ currentDir: "", repos: [], conflicts: [] })

  readonly property var scenarios: [
    { name: "main", select: 1, config: config(fourProjects), scan: { currentDir: "", repos: [], conflicts: groupKeys(5) } },
    { name: "empty", config: config([], { integration: { installed: false } }),
      scan: { currentDir: "~/code/omarchy-colorful-terminals", repos: ["~/code/omarchy-colorful-terminals", "~/code/shop", "~/code/blog", "~/Projects/dotfiles", "~/work/api-gateway"], conflicts: [] } },
    { name: "setup", config: config(fourProjects.slice(0, 2), { integration: { installed: false }, problems: [{ line: 7, text: "~/notes   green" }] }),
      scan: { currentDir: "", repos: [], conflicts: groupKeys(5) }, preview: previewText },
    { name: "setup-lines", lines: true, config: config(fourProjects.slice(0, 1), { integration: { installed: false } }),
      scan: noScan, preview: previewText },
    { name: "add", mode: "add", query: "~/co", dirs: ["~/code", "~/company"],
      config: config(fourProjects.slice(0, 3)), scan: { currentDir: "~/code/shop", repos: ["~/code/shop"], conflicts: [] } },
    { name: "hex", mode: "hex", select: 0,
      config: config([project(1, "~/code/shop", "#9aa0a6"), project(2, "~/old/gone", "#213f12", false)]), scan: noScan },
    { name: "missing", select: 1,
      config: config([project(1, "~/code/shop", "#1a3a5a"), project(2, "~/old/gone", "#213f12", false)]), scan: noScan },
    { name: "undo", select: 0, undo: true, config: config(fourProjects.slice(0, 3)), scan: noScan },
    { name: "turn-off", confirm: true, config: config(fourProjects.slice(0, 3)), scan: noScan },
    { name: "light", select: 0, light: true, config: config(fourProjects.slice(0, 3)), scan: noScan }
  ]

  FloatingWindow {
    id: window
    visible: true
    implicitWidth: 640
    implicitHeight: 1000
    color: Color.background

    Item {
      id: frame
      width: 640
      height: Math.max(test.minHeight, Math.ceil(card.height + 80))

      Rectangle { anchors.fill: parent; color: Color.background }

      // The same card PanelSurface draws.
      BorderSurface {
        id: card
        x: 40
        y: 40
        width: 560
        height: view.implicitHeight + contentTopInset + contentBottomInset
        radius: Style.cornerRadius
        color: Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
        padding: Style.spacing.panelPadding

        ProjectsView {
          id: view
          x: card.contentLeftInset
          y: card.contentTopInset
          width: card.width - card.contentLeftInset - card.contentRightInset
          dialogHost: frame
          property var lastRun: null
          property int opened: 0
          onRun: function(args) { lastRun = args.join(" ") }
          onOpenProject: function(n) { opened = n }
        }
      }
    }
  }

  function check(name, expected, actual) {
    var same = JSON.stringify(expected) === JSON.stringify(actual)
    console.log((same ? "PASS: " : "FAIL: ") + name + (same ? "" : " (expected " + expected + ", got " + actual + ")"))
  }
  function key(k, extra) {
    var e = { key: k, modifiers: 0, text: "", nativeScanCode: 0 }
    for (var name in extra || {}) e[name] = extra[name]
    view.lastRun = null
    view.handleListKey(e)
    view.settled()
    return view.lastRun
  }

  function checkKeys() {
    test.load(test.scenarios[0])
    view.selected = 1
    test.check("right arrow picks the next color", "color 2 #681e1e", key(Qt.Key_Right))
    test.check("the new color shows at once", "#681e1e", rowTint(1))
    test.check("left arrow steps back from what is shown", "color 2 #213f12", key(Qt.Key_Left))
    test.check("shift+down moves the project", "move 2 down", key(Qt.Key_Down, { modifiers: Qt.ShiftModifier }))
    test.check("selection follows the move", 2, view.selected)
    view.selected = 1
    test.check("delete removes", "remove 2", key(Qt.Key_Delete))
    test.check("undo is offered", true, view.undo !== null)
    test.check("ctrl+z puts it back in place", "add ~/code/blog #213f12 --at 2", key(Qt.Key_Z, { modifiers: Qt.ControlModifier }))
    view.busy = true
    view.lastRun = null
    view.handleListKey({ key: Qt.Key_Delete, modifiers: 0, text: "", nativeScanCode: 0 })
    test.check("no change while the last one is saving", null, view.lastRun)
    view.busy = false

    test.check("ctrl+u only asks", null, key(Qt.Key_U, { modifiers: Qt.ControlModifier }))
    test.check("the dialog is open, Cancel first", [true, 0], [turnOffOpen(), turnOffIndex()])
    test.check("enter on Cancel changes nothing", null, key(Qt.Key_Return))
    test.check("dialog closed", false, turnOffOpen())
    key(Qt.Key_U, { modifiers: Qt.ControlModifier })
    key(Qt.Key_Right)
    test.check("Turn off confirmed", "integration uninstall --yes", key(Qt.Key_Return))
    key(Qt.Key_U, { nativeScanCode: 30, modifiers: Qt.ControlModifier })
    test.check("Ctrl+U by key position (Russian layout)", true, turnOffOpen())
    key(Qt.Key_Escape)
    test.check("Esc closes the dialog, not the panel", false, turnOffOpen())

    view.selected = 1
    test.check("enter opens the selected project", 2, (key(Qt.Key_Return), view.opened))
    test.check("digit selects a row", 3, (key(Qt.Key_4), view.selected))
    view.selected = view.targets.indexOf("keys")
    test.check("space on the keys switch saves it", "set replace-group-keys yes", key(Qt.Key_Space))
    view.selected = 0
    key(0x6c4, { nativeScanCode: 38 })   // Cyrillic ф, same key as A
    test.check("A works on a Russian layout", "add", view.mode)
    view.cancelMode()
    key(0x6f3, { nativeScanCode: 54 })   // Cyrillic с, same key as C
    test.check("C (custom color) works on a Russian layout", "hex", view.mode)
    view.cancelMode()
    test.check("# starts a custom color", "hex", (key(Qt.Key_NumberSign, { text: "#" }), view.mode))
    view.cancelMode()
    view.selected = 0
    view.startHex()
    view.applyHex("12345")
    test.check("bad custom color is refused", true, view.error !== "")
    test.check("good custom color is saved", "color 1 #abcdef", (view.lastRun = null, view.applyHex("ABCDEF"), view.lastRun))
    view.startAdd()
    test.check("adding a new folder gets a free color", "add ~/code/new #621d4b", (view.lastRun = null, view.addFolder("~/code/new"), view.lastRun))
    view.startAdd()
    test.check("an existing project is not added twice", null, (view.lastRun = null, view.addFolder("~/code/shop"), view.lastRun))
    view.startAdd()
    view.query = "Ё.code"
    test.check("a path typed on the Russian layout is added", "add ~/code #621d4b", (view.lastRun = null, view.addHighlighted(), view.lastRun))

    test.load(test.scenarios[2])
    test.check("setup puts the cursor on Turn on", "install", view.target)
    test.check("turn on gives projects the keys by default", "integration install --yes --replace-group-keys yes", key(Qt.Key_Return))
    view.selected = view.targets.indexOf("setupKeys")
    key(Qt.Key_Space)
    view.selected = view.targets.indexOf("install")
    test.check("or keeps Omarchy's keys", "integration install --yes --replace-group-keys no", key(Qt.Key_Return))

    test.load(test.scenarios[6])
    view.selected = 1
    test.check("a missing folder has no color to change", null, key(Qt.Key_Right))
    test.check("and does not open", 0, (view.opened = 0, key(Qt.Key_Return), view.opened))
  }

  function rowTint(i) { return view.rowTint(i) }
  function turnOffOpen() { return view.turnOffDialog.opened }
  function turnOffIndex() { return view.turnOffDialog.selectedIndex }

  function load(s) {
    view.themeText = s.light ? "#4c4f69" : Color.foreground
    view.themeBackground = s.light ? "#eff1f5" : Color.background
    view.undo = null
    view.scan = s.scan
    view.preview = s.preview || ""
    view.config = s.config
    view.loaded = true
    view.reset()
    if (s.select !== undefined) view.selected = s.select
    if (s.lines) view.showLines = true
    if (s.undo) { view.removeSelected(); view.settled(); view.flashText = "" }
    if (s.confirm) view.askTurnOff()
    if (s.mode === "add") { view.startAdd(); view.dirs = s.dirs || [] }
    if (s.mode === "hex") view.startHex()
    if (s.query) Qt.callLater(function() { view.setQuery(s.query) })
  }

  property int minHeight: 160

  // Even ticks load a scenario, odd ticks save it once it has laid out.
  property int tick: 0
  Timer {
    id: ticker
    interval: 400
    repeat: true
    running: true
    onTriggered: {
      var index = Math.floor(test.tick / 2)
      if (index >= test.scenarios.length) { ticker.stop(); test.checkKeys(); quitTimer.start(); return }
      var s = test.scenarios[index]
      if (test.tick % 2 === 0) {
        test.minHeight = s.confirm ? 380 : 160
        test.load(s)
      } else {
        var h = frame.height
        if (card.height < 120) console.log("FAIL: " + s.name + " rendered too small: " + card.height)
        // Twice the size, so the PNGs are sharp enough to review.
        frame.grabToImage(function(result) {
          var file = test.outDir + "/" + s.name + ".png"
          if (result.saveToFile(file)) console.log("PASS: rendered " + s.name + " (" + h + "px)")
          else console.log("FAIL: could not save " + file)
        }, Qt.size(frame.width * 2, h * 2))
      }
      test.tick++
    }
  }
  Timer { id: quitTimer; interval: 800; onTriggered: Qt.quit() }
}
