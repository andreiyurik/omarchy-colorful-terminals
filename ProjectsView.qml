import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The settings panel content. Knows nothing about windows or processes: it
// shows `config`/`scan` from the helper and asks for changes through `run`.
// Every change is saved immediately; there is no Save button.
FocusScope {
  id: projectsView

  // From the helper (`colorful-terminals state` and `scan`).
  property var config: ({ projects: [], palette: [], problems: [], integration: { installed: true }, replaceGroupKeys: false })
  property var scan: ({ currentDir: "", repos: [], conflicts: [] })
  property var dirs: []
  property string preview: ""
  property bool loaded: false
  // Where the Turn off dialog draws its scrim; the whole window when hosted.
  property Item dialogHost: null

  property string fontFamily: Style.font.menuFamily
  property color text: Color.menu.text
  property color accent: Color.accent
  property color urgent: Color.urgent
  property color themeText: Color.foreground
  property color themeBackground: Color.background
  property real maxListHeight: Style.space(420)

  signal run(var args)
  signal openProject(int n)
  signal closeRequested()
  signal queryDirs(string path)

  // UI state.
  property string mode: "list"          // list | add | hex
  property int selected: 0              // index into `targets`
  property int addSelected: 0
  property string query: ""
  property string hexPreview: ""
  property string error: ""             // the last failure, until the next change
  property string note: ""              // a quiet line, e.g. after turning on
  property string flashText: ""         // "Saved" in the header, for a moment
  property var undo: null               // last removed project, for Ctrl+Z
  property bool showLines: false
  property bool setupReplace: true
  property int selectAfterRefresh: -1
  // True from a change until the fresh state is back, so a fast second key
  // press cannot act on an old list (and move the wrong project).
  property bool busy: false

  readonly property var projects: (config && config.projects) || []
  readonly property bool lightTheme: Model.isLightTheme(String(themeBackground))
  // Pale tints on a light theme, deep ones on a dark theme.
  readonly property var palette: (config && (lightTheme && config.paletteLight && config.paletteLight.length
    ? config.paletteLight : config.palette)) || []
  readonly property bool colorsNeedWork: {
    for (var i = 0; i < projects.length; i++)
      if (Model.colorIssue(projects[i].color, String(themeText), String(themeBackground))) return true
    return false
  }
  readonly property bool empty: loaded && projects.length === 0
  readonly property bool installed: !!(config && config.integration && config.integration.installed)
  readonly property bool adding: mode === "add" || empty
  readonly property bool needsSetup: loaded && !installed && projects.length > 0
  readonly property var conflicts: Model.conflictsFor(scan.conflicts, projects.length)
  readonly property bool showKeys: installed && (conflicts.length > 0 || !!config.replaceGroupKeys)
  readonly property var rows: Model.suggestions(query, scan.currentDir, scan.repos, dirs, projects)

  // Everything the keyboard cursor can land on, top to bottom.
  readonly property var targets: {
    var t = []
    for (var i = 0; i < projects.length; i++) t.push("project")
    t.push("add")
    if (showKeys) t.push("keys")
    if (needsSetup && conflicts.length) t.push("setupKeys")
    if (needsSetup) t.push("install")
    return t
  }
  readonly property string target: targets[selected] || ""
  readonly property var current: target === "project" ? projects[selected] : null

  readonly property string keysLabel: "Super+Alt+"
    + (conflicts.length ? Model.digitRange(conflicts.map(function(c) { return c.digit })) : "1–9")
    + " open projects"
  function keysDescription(on) {
    var own = conflicts.filter(function(c) { return !c.byCode })
    var text = on ? "Omarchy's group-tab keys step aside. Super+Alt+Tab still switches tabs."
                  : "Omarchy also uses them to switch group tabs."
    if (own.length) text += " Your own binding on Super+Alt+" + own[0].digit + " stays; change it in ~/.config/hypr/bindings.lua."
    return text
  }

  readonly property color dim: Util.alpha(text, 0.62)
  readonly property alias turnOffDialog: turnOff

  function rowTint(i) { return i < rowModel.count ? rowModel.get(i).tint : "" }
  function setQuery(value) { addView.setText(value) }

  implicitHeight: layout.implicitHeight

  // ------------------------------------------------------------- actions

  function request(args) {
    busy = true
    error = ""
    note = ""
    run(args)
  }

  // Called by the controller once the state after a change has been read.
  function settled() {
    busy = false
  }

  function flash(textValue) {
    flashText = Model.plain(textValue, 60)
    flashTimer.restart()
  }

  // Called by the controller when a helper command finishes.
  function finished(args, ok, out, err) {
    if (!ok) {
      error = Model.plain(String(err || out || "Something went wrong").split("\n")[0].replace(/^colorful-terminals: /, ""), 160)
      return
    }
    if (args[0] === "integration" && args[1] === "install") {
      flash("On")
      selectAfterRefresh = 0
      note = projects.length
        ? "Colorful Terminals is on. Press Enter to open " + Model.plain(projects[0].name, 40)
          + " in its color. Terminals that were already open get colors once you open them again."
        : "Colorful Terminals is on."
    } else if (args[0] === "integration" && args[1] === "uninstall") {
      note = "Turned off. New terminals use the theme color; your projects are kept."
    } else if (args[0] === "remove") {
      flash("Removed")
    } else if (args[0] === "add") {
      flash("Added")
    } else {
      flash("Saved")
    }
  }

  // A config change handler runs before the bindings that read `config`
  // (projects, targets) have caught up, so rows are built from `config` itself
  // and the cursor is placed once everything has settled.
  function configUpdated() {
    syncRows((config && config.projects) || [])
    Qt.callLater(placeCursor)
  }
  onConfigChanged: configUpdated()

  function placeCursor() {
    if (selectAfterRefresh >= 0) {
      selected = selectAfterRefresh
      selectAfterRefresh = -1
    }
    selected = Math.max(0, Math.min(selected, targets.length - 1))
    if (empty && addView.visible) addView.focusField()
  }

  // The list keeps its rows and updates them in place, so a new color fades
  // in instead of the whole list being rebuilt.
  ListModel { id: rowModel }
  function syncRows(list) {
    var fields = ["n", "name", "path", "tint", "exists"]
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      var next = { n: p.n, name: p.name, path: p.path, tint: Model.hexOf(p.color), exists: p.exists !== false }
      if (i >= rowModel.count) { rowModel.append(next); continue }
      for (var f = 0; f < fields.length; f++) {
        if (rowModel.get(i)[fields[f]] !== next[fields[f]]) rowModel.setProperty(i, fields[f], next[fields[f]])
      }
    }
    while (rowModel.count > list.length) rowModel.remove(rowModel.count - 1)
  }

  function reset() {
    mode = "list"
    query = ""
    addSelected = 0
    error = ""
    note = ""
    hexPreview = ""
    showLines = false
    setupReplace = config && config.replaceGroupKeysSet ? !!config.replaceGroupKeys : true
    selected = needsSetup ? targets.length - 1 : 0
    turnOff.opened = false
    if (empty) addView.focusField()
    else keyCatcher.forceActiveFocus()
  }

  function pointAt(kind) {
    var i = targets.indexOf(kind)
    if (i >= 0 && mode === "list") selected = i
  }

  function pointRow(index, item, mouse) {
    if (mode === "list" && pointerGate.moved(item, mouse)) selected = index
  }

  function setColor(n, color) {
    var c = Model.hexOf(color)
    if (!c) { error = "Colors look like #1a3a5a"; return }
    if (n - 1 < rowModel.count) rowModel.setProperty(n - 1, "tint", c)
    request(["color", String(n), c])
  }

  function stepColor(step) {
    if (!current || !current.exists) return
    setColor(current.n, Model.stepColor(palette, rowModel.get(selected).tint, step))
  }

  function move(step) {
    if (!current) return
    var to = selected + step
    if (to < 0 || to >= projects.length) return
    request(["move", String(current.n), step < 0 ? "up" : "down"])
    selected = to
  }

  function removeSelected() {
    if (!current) return
    undo = { n: current.n, path: current.path, color: current.color, name: current.name }
    request(["remove", String(current.n)])
  }

  function undoRemove() {
    if (!undo) return
    request(["add", undo.path, undo.color, "--at", String(undo.n)])
    selectAfterRefresh = undo.n - 1
    undo = null
  }

  function startAdd() {
    mode = "add"
    query = ""
    addSelected = 0
    addView.setText("")
    Qt.callLater(function() { addView.focusField() })
  }

  function addFolder(path) {
    if (!path) return
    var taken = Model.projectNumber(projects, path)
    if (taken) { error = path + " is already project " + taken; return }
    request(["add", path, Model.freeColor(palette, projects, String(themeText), String(themeBackground))])
    selectAfterRefresh = projects.length
    mode = "list"
    query = ""
    keyCatcher.forceActiveFocus()
  }

  function addHighlighted() {
    var row = rows[addSelected]
    var q = Model.folderQuery(query)
    if (row) addFolder(row.path)
    else if (Model.isPathQuery(q)) addFolder(q)
  }

  function completeHighlighted() {
    var row = rows[addSelected]
    if (!row) return
    addView.setText(row.path === "~" ? "~/" : row.path + "/")
  }

  function startHex() {
    if (!current || !current.exists) return
    hexPreview = Model.hexOf(current.color)
    mode = "hex"
  }

  function applyHex(value) {
    var c = Model.hexOf(value)
    if (!c) { error = "Type a color like #1a3a5a"; return }
    setColor(current.n, c)
    mode = "list"
    hexPreview = ""
    keyCatcher.forceActiveFocus()
  }

  function cancelMode() {
    mode = "list"
    query = ""
    hexPreview = ""
    keyCatcher.forceActiveFocus()
  }

  function install() {
    var args = ["integration", "install", "--yes"]
    if (conflicts.length) args.push("--replace-group-keys", setupReplace ? "yes" : "no")
    request(args)
  }

  function askTurnOff() {
    if (!installed) return
    turnOff.selectedIndex = 0
    turnOff.opened = true
  }

  function toggleReplace() {
    request(["set", "replace-group-keys", config.replaceGroupKeys ? "no" : "yes"])
  }

  function activate() {
    if (target === "project") { if (current.exists) openProject(current.n) }
    else if (target === "add") startAdd()
    else if (target === "keys") toggleReplace()
    else if (target === "setupKeys") setupReplace = !setupReplace
    else if (target === "install") install()
  }

  // Letter keys by position too, so they work on any keyboard layout
  // (xkb keycodes: A 38, C 54, U 30, Z 52).
  readonly property var scanCodes: ({ A: 38, C: 54, U: 30, Z: 52 })
  function letter(event, name) {
    return event.key === Qt["Key_" + name] || event.nativeScanCode === scanCodes[name]
  }

  function handleListKey(event) {
    if (turnOff.opened) return turnOff.handleKey(event)
    var shift = event.modifiers & Qt.ShiftModifier
    var ctrl = event.modifiers & Qt.ControlModifier
    var changes = event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Delete
      || event.key === Qt.Key_Backspace || ((event.key === Qt.Key_Up || event.key === Qt.Key_Down) && shift)
    if (busy && changes) return true
    pointerGate.reset()

    if (event.key === Qt.Key_Escape) closeRequested()
    else if (event.key === Qt.Key_Up && shift) move(-1)
    else if (event.key === Qt.Key_Down && shift) move(1)
    else if (event.key === Qt.Key_Up) selected = Math.max(0, selected - 1)
    else if (event.key === Qt.Key_Down) selected = Math.min(targets.length - 1, selected + 1)
    else if (event.key === Qt.Key_Left) stepColor(-1)
    else if (event.key === Qt.Key_Right) stepColor(1)
    else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) removeSelected()
    else if (letter(event, "Z") && ctrl) undoRemove()
    else if (letter(event, "U") && ctrl) askTurnOff()
    else if ((letter(event, "A") && !ctrl) || event.key === Qt.Key_Plus || event.key === Qt.Key_Insert) startAdd()
    else if (event.text === "#" || (letter(event, "C") && !ctrl)) startHex()
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activate()
    else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !ctrl) {
      selected = Math.min(projects.length - 1, event.key - Qt.Key_1)
    } else return false
    return true
  }

  Timer {
    id: flashTimer
    interval: 1800
    onTriggered: projectsView.flashText = ""
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: projectsView
  }

  ConfirmDialog {
    id: turnOff
    parent: projectsView.dialogHost || view
    anchors.fill: parent
    z: 100
    message: "Turn off Colorful Terminals? This takes its blocks out of your shell, Hyprland and menu config. Your projects are kept."
    confirmText: "Turn off"
    fontFamily: projectsView.fontFamily
    background: Color.menu.background
    foreground: projectsView.text
    onCanceled: { opened = false; keyCatcher.forceActiveFocus() }
    onConfirmed: {
      opened = false
      projectsView.request(["integration", "uninstall", "--yes"])
      keyCatcher.forceActiveFocus()
    }
  }

  // --------------------------------------------------------------- layout

  Item {
    id: keyCatcher
    focus: true
    Keys.onPressed: function(event) {
      if (projectsView.mode === "list" && !projectsView.empty) event.accepted = projectsView.handleListKey(event)
    }
  }

  Column {
    id: layout
    width: parent.width
    spacing: Style.space(12)

    PanelHero {
      id: hero
      width: parent.width
      title: "Colorful Terminals"
      meta: Model.summary(projectsView.projects.length)
      foreground: projectsView.text
      fontFamily: projectsView.fontFamily
      iconComponent: Component {
        Text {
          textFormat: Text.PlainText
          text: "󰏘"
          color: projectsView.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }
      }
      trailingControl: Component {
        Text {
          textFormat: Text.PlainText
          text: "✓ " + (projectsView.flashText || "Saved")
          color: projectsView.dim
          font.family: projectsView.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          opacity: projectsView.flashText !== "" ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: projectsView.flashText !== "" ? 120 : 400; easing.type: Easing.OutCubic } }
        }
      }
    }

    // Quiet status lines: an error, a note, a hand-edit problem, a light theme.
    Column {
      width: parent.width
      spacing: Style.spacing.sm
      visible: projectsView.error !== "" || projectsView.note !== "" || problemsText.problems.length > 0 || themeLine.visible

      Text {
        visible: projectsView.error !== ""
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.WordWrap
        text: projectsView.error
        color: projectsView.urgent
        font.family: projectsView.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        visible: projectsView.note !== ""
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.WordWrap
        text: projectsView.note
        color: projectsView.text
        font.family: projectsView.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        id: problemsText
        readonly property var problems: projectsView.config.problems || []
        visible: problems.length > 0
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.WordWrap
        text: {
          if (!problems.length) return ""
          var first = problems[0]
          return "Skipped " + problems.length + (problems.length === 1 ? " line" : " lines") + " in "
            + Model.plain(projectsView.config.file || "projects.conf", 80) + ". Line " + first.line + ": “"
            + Model.plain(first.text, 50) + "”. A project line is a folder and a color, like ~/code/shop #1a3a5a."
        }
        color: projectsView.urgent
        font.family: projectsView.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        id: themeLine
        visible: projectsView.colorsNeedWork
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.WordWrap
        text: projectsView.lightTheme
          ? "Your theme is light. Colors marked with a dot were picked for a dark theme; pick a light one from the palette."
          : "Colors marked with a dot are hard to read on this theme; pick another from the palette."
        color: projectsView.dim
        font.family: projectsView.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    PanelSeparator { foreground: projectsView.text }

    // Project list
    Flickable {
      id: listFlick
      visible: !projectsView.adding
      width: parent.width
      height: Math.min(listColumn.implicitHeight, projectsView.maxListHeight)
      contentHeight: listColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: listColumn
        width: parent.width
        spacing: Style.spacing.xs

        Repeater {
          model: rowModel
          delegate: ProjectRow {
            width: listColumn.width
            view: projectsView
            hasCursor: projectsView.selected === index && projectsView.target === "project"
            onPointed: function(item, mouse) { projectsView.pointRow(index, item, mouse) }
            onPicked: { if (projectsView.mode === "hex") projectsView.cancelMode(); projectsView.selected = index }
            onYChanged: if (hasCursor) projectsView.ensureVisible(y, height)
            onHeightChanged: if (hasCursor) projectsView.ensureVisible(y, height)
            onHasCursorChanged: if (hasCursor) projectsView.ensureVisible(y, height)
          }
        }

        // Add project
        CursorSurface {
          id: addRow
          width: listColumn.width
          height: Style.space(32) + Style.spacing.rowPaddingX
          hasCursor: projectsView.target === "add"
          foreground: projectsView.text
          accent: projectsView.accent
          onHasCursorChanged: if (hasCursor) projectsView.ensureVisible(y, height)

          Rectangle {
            id: plusTile
            x: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(32)
            height: width
            radius: Style.cornerRadius
            color: "transparent"
            border.color: Util.alpha(projectsView.text, addRow.hasCursor ? 0.5 : 0.25)
            border.width: 1
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: "+"
              color: addRow.hasCursor ? projectsView.accent : projectsView.dim
              font.family: projectsView.fontFamily
              font.pixelSize: Style.font.heading
            }
          }
          Text {
            textFormat: Text.PlainText
            anchors.left: plusTile.right
            anchors.leftMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: "Add project"
            color: addRow.hasCursor ? projectsView.text : projectsView.dim
            font.family: projectsView.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
          MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) { projectsView.pointRow(projectsView.targets.indexOf("add"), addMouse, mouse) }
            onClicked: projectsView.startAdd()
          }
        }
      }
    }

    AddProject {
      id: addView
      visible: projectsView.adding
      width: parent.width
      view: projectsView
    }

    // Super+Alt+digit keys, only when Omarchy uses them too
    Column {
      visible: projectsView.showKeys && !projectsView.adding
      width: parent.width
      spacing: Style.space(12)

      PanelSeparator { foreground: projectsView.text }

      Toggle {
        width: parent.width
        label: projectsView.keysLabel
        description: projectsView.keysDescription(!!projectsView.config.replaceGroupKeys)
        checked: !!projectsView.config.replaceGroupKeys
        hasCursor: projectsView.target === "keys"
        foreground: projectsView.text
        accent: projectsView.accent
        fontFamily: projectsView.fontFamily
        onClicked: projectsView.toggleReplace()
        onHovered: function(on) { if (on) projectsView.pointAt("keys") }
      }
    }

    // One-time setup
    Column {
      visible: projectsView.needsSetup && !projectsView.adding
      width: parent.width
      spacing: Style.space(12)

      PanelSeparator { foreground: projectsView.text }
      TurnOn {
        width: parent.width
        view: projectsView
      }
    }

    PanelSeparator { foreground: projectsView.text }

    // Footer: the few keys that matter here, and a quiet way out.
    Item {
      width: parent.width
      height: Math.max(hintRow.implicitHeight, footerButton.implicitHeight)

      Row {
        id: hintRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(12)
        Repeater {
          model: Model.hints({
            mode: projectsView.adding ? "add" : projectsView.mode, empty: projectsView.empty, target: projectsView.target,
            missing: !!(projectsView.current && !projectsView.current.exists)
          })
          delegate: Row {
            required property var modelData
            spacing: Style.spacing.sm
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: keyText.implicitWidth + Style.spacing.md * 2
              height: keyText.implicitHeight + Style.spacing.xxs * 2
              radius: Style.cornerRadius
              color: Util.alpha(projectsView.text, 0.08)
              Text {
                id: keyText
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: modelData[0]
                color: projectsView.text
                font.family: projectsView.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: modelData[1]
              color: projectsView.dim
              font.family: projectsView.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Button {
        id: footerButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !projectsView.adding && (projectsView.undo !== null || projectsView.installed)
        text: projectsView.undo ? "Undo remove" : "Turn off…"
        tooltipText: projectsView.undo ? "Ctrl+Z" : "Ctrl+U"
        foreground: projectsView.undo ? projectsView.text : projectsView.dim
        fontFamily: projectsView.fontFamily
        fontSize: Style.font.caption
        verticalPadding: Style.spacing.xxs
        onClicked: projectsView.undo ? projectsView.undoRemove() : projectsView.askTurnOff()
      }
    }
  }

  function ensureVisible(y, h) {
    if (y < listFlick.contentY) listFlick.contentY = y
    else if (y + h > listFlick.contentY + listFlick.height) listFlick.contentY = y + h - listFlick.height
  }
}
