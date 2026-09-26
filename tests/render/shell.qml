import QtQuick
import Quickshell
import qs.Commons

// Renders the settings panel offscreen in several states and saves PNGs.
// Run by tests/render-panel; prints PASS/FAIL lines.
ShellRoot {
  id: test

  readonly property string outDir: Quickshell.env("CT_RENDER_DIR")

  readonly property var palette: [
    { name: "Blue", color: "#1a3a5a" }, { name: "Green", color: "#213f12" }, { name: "Red", color: "#681e1e" },
    { name: "Violet", color: "#4c2276" }, { name: "Olive", color: "#3b3a11" }, { name: "Teal", color: "#133e42" },
    { name: "Plum", color: "#621d4b" }, { name: "Brown", color: "#4c3316" }, { name: "Indigo", color: "#262e82" },
    { name: "Jade", color: "#13402a" }
  ]
  function project(n, path, color, exists) {
    var name = path.split("/").pop()
    return { n: n, path: path, abs: path, color: color, name: name, exists: exists !== false }
  }
  readonly property var fourProjects: [
    project(1, "~/code/shop", "#1a3a5a"), project(2, "~/code/blog", "#213f12"),
    project(3, "~/work/api-gateway", "#681e1e"), project(4, "~/work/api-gateway/admin", "#4c2276")
  ]
  readonly property string previewText: "~/.bashrc  (at the end)\n    # BEGIN colorful-terminals (...)\n    if [[ -r \"$HOME\"/.config/omarchy/plugins/andreiyurik.colorful-terminals/shell/colorful-terminals.bash ]]; then source ...; fi\n    # END colorful-terminals\n\n~/.config/hypr/hyprland.lua  (at the end)\n    -- BEGIN colorful-terminals (...)\n    do local dir = os.getenv(\"HOME\") .. \"/.config/omarchy/plugins/andreiyurik.colorful-terminals\"; ... end\n    -- END colorful-terminals"

  readonly property var scenarios: [
    { name: "main", select: 1, config: { projects: fourProjects, palette: palette, problems: [], integration: { installed: true }, replaceGroupKeys: false },
      scan: { currentDir: "~/code/shop", repos: [], conflicts: [] } },
    { name: "empty", config: { projects: [], palette: palette, problems: [], integration: { installed: false }, replaceGroupKeys: false },
      scan: { currentDir: "~/code/omarchy-colorful-terminals", repos: ["~/code/shop", "~/code/blog", "~/Projects/dotfiles", "~/work/api-gateway"], conflicts: [] } },
    { name: "setup", config: { projects: fourProjects.slice(0, 2), palette: palette, problems: [{ line: 7, text: "~/notes   green" }], integration: { installed: false }, replaceGroupKeys: false },
      scan: { currentDir: "", repos: [], conflicts: [{ digit: 1, description: "Switch to group window 1", byCode: true }, { digit: 2, description: "Switch to group window 2", byCode: true }] }, preview: previewText },
    { name: "add", mode: "add", query: "~/co", dirs: ["~/code", "~/company"],
      config: { projects: fourProjects.slice(0, 3), palette: palette, problems: [], integration: { installed: true }, replaceGroupKeys: true },
      scan: { currentDir: "~/code/shop", repos: ["~/code/shop"], conflicts: [] } },
    { name: "hex", mode: "hex", select: 0, config: { projects: [project(1, "~/code/shop", "#9aa0a6"), project(2, "~/old/gone", "#213f12", false)], palette: palette, problems: [], integration: { installed: true }, replaceGroupKeys: false },
      scan: { currentDir: "", repos: [], conflicts: [] } }
  ]

  FloatingWindow {
    id: window
    visible: true
    implicitWidth: 720
    implicitHeight: 760
    color: Color.menu.background

    Rectangle {
      id: frame
      anchors.fill: parent
      color: Color.menu.background
      ProjectsView {
        id: view
        x: 24
        y: 24
        width: parent.width - 48
        property var lastRun: null
        property int opened: 0
        onRun: function(args) { lastRun = args.join(" ") }
        onOpenProject: function(n) { opened = n }
      }
    }
  }

  function check(name, expected, actual) {
    console.log((expected === actual ? "PASS: " : "FAIL: ") + name + (expected === actual ? "" : " (expected " + expected + ", got " + actual + ")"))
  }
  function key(k, extra) {
    var e = { key: k, modifiers: 0, text: "", nativeScanCode: 0 }
    for (var name in extra || {}) e[name] = extra[name]
    view.lastRun = null
    view.handleListKey(e)
    view.settled()
    return view.lastRun
  }
  // Keyboard handling, with fake key events on the "main" scenario.
  function checkKeys() {
    test.load(test.scenarios[0])
    view.selected = 1
    test.check("right arrow picks the next color", "color 2 #681e1e", key(Qt.Key_Right))
    test.check("left arrow picks the previous color", "color 2 #1a3a5a", key(Qt.Key_Left))
    test.check("shift+down moves the project", "move 2 down", key(Qt.Key_Down, { modifiers: Qt.ShiftModifier }))
    test.check("selection follows the move", 2, view.selected)
    view.selected = 1
    test.check("delete removes", "remove 2", key(Qt.Key_Delete))
    test.check("ctrl+z puts it back in place", "add ~/code/blog #213f12 --at 2", key(Qt.Key_Z, { modifiers: Qt.ControlModifier }))
    view.busy = true
    view.lastRun = null
    view.handleListKey({ key: Qt.Key_Delete, modifiers: 0, text: "", nativeScanCode: 0 })
    test.check("no change while the last one is saving", null, view.lastRun)
    view.busy = false
    test.check("ctrl+u asks first", null, key(Qt.Key_U, { modifiers: Qt.ControlModifier }))
    test.check("ctrl+u twice uninstalls", "integration uninstall --yes", key(Qt.Key_U, { modifiers: Qt.ControlModifier }))
    test.check("enter opens the selected project", 2, (key(Qt.Key_Return), view.opened))
    test.check("digit selects a row", 3, (key(Qt.Key_4), view.selected))
    key(0x6c4, { nativeScanCode: 38 })   // Cyrillic ф, same key as A
    test.check("A works on a Russian layout", "add", view.mode)
    view.cancelMode()
    test.check("# starts a custom color", "hex", (key(Qt.Key_NumberSign, { text: "#" }), view.mode))
    view.cancelMode()
    view.selected = 0
    view.applyHex("12345")
    test.check("bad custom color is refused", true, view.messageIsError)
    view.mode = "hex"
    test.check("good custom color is saved", "color 1 #abcdef", (view.lastRun = null, view.applyHex("ABCDEF"), view.lastRun))
    view.startAdd()
    view.query = ""
    test.check("adding a new folder gets a free color", "add ~/code/new #3b3a11", (view.lastRun = null, view.addFolder("~/code/new"), view.lastRun))
    test.check("an existing project is not added twice", null, (view.lastRun = null, view.addFolder("~/code/shop"), view.lastRun))
  }

  function load(s) {
    view.reset()
    view.scan = s.scan
    view.preview = s.preview || ""
    view.config = s.config
    view.loaded = true
    view.selected = s.select || 0
    if (s.mode === "add") { view.startAdd(); view.dirs = s.dirs || [] }
    if (s.mode === "hex") view.startHex()
    if (s.query) Qt.callLater(function() { view.query = s.query })
  }

  // Even ticks load a scenario, odd ticks save it once it has laid out.
  property int tick: 0
  Timer {
    id: ticker
    interval: 350
    repeat: true
    running: true
    onTriggered: {
      var index = Math.floor(test.tick / 2)
      if (index >= test.scenarios.length) { ticker.stop(); test.checkKeys(); quitTimer.start(); return }
      var s = test.scenarios[index]
      if (test.tick % 2 === 0) {
        test.load(s)
      } else {
        var h = Math.ceil(view.implicitHeight + 48)
        if (h < 100) console.log("FAIL: " + s.name + " rendered too small: " + h)
        frame.grabToImage(function(result) {
          var file = test.outDir + "/" + s.name + ".png"
          if (result.saveToFile(file)) console.log("PASS: rendered " + s.name + " (" + h + "px)")
          else console.log("FAIL: could not save " + file)
        }, Qt.size(720, Math.min(760, h)))
      }
      test.tick++
    }
  }
  Timer { id: quitTimer; interval: 800; onTriggered: Qt.quit() }
}
