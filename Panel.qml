import Quickshell
import Quickshell.Io
import QtQuick

// Colorful Terminals settings panel. Summoned with Super+Ctrl+Alt+0, from the
// Omarchy menu (Style > Colorful Terminals), or with:
//   omarchy-shell shell toggle andreiyurik.colorful-terminals '{}'
// This file holds the state and talks to bin/colorful-terminals, always with
// an argv array, never a shell string. PanelSurface.qml draws the window and
// is only loaded while the panel is open.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool showWindow: true        // tests turn this off: no Wayland offscreen
  readonly property string pluginId: (manifest && manifest.id) || "andreiyurik.colorful-terminals"
  readonly property string helper: decodeURIComponent(
    Qt.resolvedUrl("bin/colorful-terminals").toString().replace("file://", ""))
  readonly property int outputLimit: 512 * 1024

  // What the view shows, from `colorful-terminals state`, `scan`, `dirs`, and
  // `integration preview`.
  property var config: null
  property var scan: ({ currentDir: "", repos: [], conflicts: [] })
  property var dirs: []
  property string dirsQuery: ""
  property string preview: ""
  property string lastStateJson: ""
  property int stateCallsInFlight: 0

  signal commandFinished(var args, bool ok, string out, string err)
  signal changeSettled()

  function open(payloadJson) {
    root.opened = true
    refresh()
    rescan()
    call(["integration", "preview"], function(ok, out) { if (ok) root.preview = out.trim() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function parse(out, fallback) {
    try { return JSON.parse(out) } catch (e) { return fallback }
  }

  function refresh() {
    if (stateCallsInFlight > 0) return
    stateCallsInFlight++
    call(["state"], function(ok, out) {
      stateCallsInFlight--
      if (!ok || out === lastStateJson) return
      var next = parse(out, null)
      if (!next) return
      lastStateJson = out
      root.config = next
    })
  }

  function rescan() {
    call(["scan"], function(ok, out) { if (ok) root.scan = parse(out, root.scan) })
  }

  // A change asked for by the view. Saved at once; the state is re-read after.
  function change(args) {
    call(args, function(ok, out, err) {
      root.commandFinished(args, ok, out, err)
      call(["state"], function(stateOk, stateOut) {
        var next = stateOk ? parse(stateOut, null) : null
        if (next && stateOut !== root.lastStateJson) {
          root.lastStateJson = stateOut
          root.config = next
        }
        root.changeSettled()
      })
      if (args[0] === "integration") root.rescan()
    })
  }

  function openProject(n) {
    root.dismiss()
    // Detached: the helper becomes the terminal, which must outlive the panel.
    Quickshell.execDetached([root.helper, "open", String(n)])
  }

  function queryDirs(path) {
    root.dirsQuery = path
    call(["dirs", path], function(ok, out) {
      if (ok && root.dirsQuery === path) root.dirs = parse(out, [])
    })
  }

  // Runs the helper with argv and calls done(ok, stdout, stderr). Output is
  // capped, and a helper that hangs is stopped after ten seconds.
  function call(args, done) {
    var proc = processComponent.createObject(root, { args: args, done: done })
    proc.command = [root.helper].concat(args)
    proc.running = true
  }

  Component {
    id: processComponent
    Process {
      id: proc
      property var args: []
      property var done: null
      property string out: ""
      property string err: ""
      property bool finished: false

      function take(current, data) {
        var next = current + data + "\n"
        return next.length > root.outputLimit ? next.substr(0, root.outputLimit) : next
      }

      stdout: SplitParser { onRead: function(data) { proc.out = proc.take(proc.out, data) } }
      stderr: SplitParser { onRead: function(data) { proc.err = proc.take(proc.err, data) } }

      onExited: function(exitCode) {
        if (proc.finished) return
        proc.finished = true
        deadline.stop()
        if (proc.done) proc.done(exitCode === 0, proc.out, proc.err)
        proc.destroy()
      }

      property Timer deadline: Timer {
        interval: 10000
        running: true
        onTriggered: proc.running = false
      }
    }
  }

  // Picks up hand edits of projects.conf while the panel is open.
  FileView {
    path: Quickshell.env("HOME") + "/.config/colorful-terminals/projects.conf"
    watchChanges: root.opened
    printErrors: false
    onFileChanged: { reload(); root.refresh() }
  }

  Loader {
    active: root.opened && root.showWindow
    source: "PanelSurface.qml"
    onLoaded: item.controller = root
  }
}
