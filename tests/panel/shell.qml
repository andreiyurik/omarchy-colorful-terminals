import QtQuick
import Quickshell

// Loads the real Panel.qml offscreen and drives it through the helper with a
// temporary HOME: state, add, recolor, and the command-failure path.
ShellRoot {
  id: test
  Panel {
    id: panel
    showWindow: false
    onChangeSettled: test.check("change settles with the new state", panel.lastStateJson.indexOf("#0a0b0c") >= 0)
  }

  property int phase: 0
  function check(name, condition) { console.log((condition ? "PASS: " : "FAIL: ") + name) }

  Timer {
    interval: 600
    repeat: true
    running: true
    onTriggered: {
      var dir = Quickshell.env("CT_TEST_DIR")
      switch (test.phase++) {
      case 0:
        panel.open("{}")
        break
      case 1:
        var s = JSON.parse(panel.lastStateJson || "{}")
        test.check("panel loaded state through the helper", s.projects && s.projects.length === 1)
        test.check("helper path resolved", panel.helper.indexOf("/bin/colorful-terminals") > 0)
        panel.call(["add", dir + "/second"], function(ok, out) {
          test.check("add through Process", ok && out.indexOf("project 2") >= 0)
          panel.refresh()
        })
        break
      case 2:
        test.check("refresh picked up the new project", JSON.parse(panel.lastStateJson).projects.length === 2)
        panel.call(["color", "9", "#123456"], function(ok, out, err) {
          test.check("failure reported with stderr", !ok && err.indexOf("there is no project 9") >= 0)
        })
        break
      case 3:
        var before = panel.lastStateJson
        panel.call(["color", "1", "#654321"], function(ok) { test.check("recolor", ok) })
        break
      case 4:
        panel.refresh()
        break
      case 5:
        test.check("state shows new color", panel.lastStateJson.indexOf("#654321") >= 0)
        panel.change(["color", "1", "#0A0B0C"])
        break
      case 6:
        // A hand edit that replaces the file, the way editors save.
        panel.call(["add", dir + "/third"], function(ok) {})
        break
      case 7:
        var viaWatch = JSON.parse(panel.lastStateJson).projects.length === 3
        test.check("hand edits show up without polling", viaWatch)
        panel.toggle()
        test.check("toggle closes", !panel.opened)
        Qt.quit()
        break
      }
    }
  }
}
