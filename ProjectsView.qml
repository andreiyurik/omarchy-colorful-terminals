import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The settings panel content. Knows nothing about windows or processes: it
// shows `config`/`scan` from the helper and asks for changes through `run`.
// Every change is saved immediately; there is no Save button.
FocusScope {
  id: root

  // From the helper (`colorful-terminals state` and `scan`).
  property var config: ({ projects: [], palette: [], problems: [], integration: { installed: true }, replaceGroupKeys: false })
  property var scan: ({ currentDir: "", repos: [], conflicts: [] })
  property var dirs: []
  property string preview: ""
  property bool loaded: false

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
  property int selected: 0              // project index; projects.length = "Add project" row
  property int addSelected: 0
  property string query: ""
  property string message: ""
  property bool messageIsError: false
  property var undo: null               // last removed project, for Ctrl+Z
  property bool confirmUninstall: false
  property int selectAfterRefresh: -1
  // True from a change until the fresh state is back, so a fast second key
  // press cannot act on an old list (and move the wrong project).
  property bool busy: false

  readonly property var projects: (config && config.projects) || []
  readonly property var palette: (config && config.palette) || []
  readonly property bool empty: loaded && projects.length === 0
  readonly property bool installed: !!(config && config.integration && config.integration.installed)
  readonly property bool adding: mode === "add" || empty
  readonly property var current: selected < projects.length ? projects[selected] : null
  readonly property var rows: Model.suggestions(query, scan.currentDir, scan.repos, dirs, projects)
  readonly property var conflicts: Model.conflictsFor(scan.conflicts, projects.length)
  readonly property bool lightTheme: Model.isLightTheme(String(themeBackground))

  readonly property color dim: Util.alpha(text, 0.62)
  readonly property color faint: Util.alpha(text, 0.16)
  readonly property int gap: Style.spacing.rowGap
  readonly property int pad: Style.spacing.rowPaddingX
  readonly property int rowHeight: Style.space(46)

  implicitHeight: layout.implicitHeight

  // ------------------------------------------------------------- actions

  function request(args) {
    busy = true
    run(args)
  }

  // Called by the controller once the state after a change has been read.
  function settled() {
    busy = false
  }

  function say(textValue, isError) {
    message = Model.plain(textValue, 160)
    messageIsError = !!isError
  }

  // Called by the controller when a helper command finishes.
  function finished(args, ok, out, err) {
    if (!ok) {
      say(String(err || out || "Something went wrong").split("\n")[0].replace(/^colorful-terminals: /, ""), true)
      return
    }
    var first = String(out || "").split("\n")[0]
    if (args[0] === "integration" && args[1] === "install") first = "Done. Open a new terminal to see project colors."
    if (args[0] === "integration" && args[1] === "uninstall") first = "Integration removed. New terminals use the theme color."
    if (first) say(first, false)
  }

  function configUpdated() {
    if (selectAfterRefresh >= 0) {
      selected = Math.min(selectAfterRefresh, projects.length)
      selectAfterRefresh = -1
    }
    selected = Math.max(0, Math.min(selected, projects.length))
    if (empty && !folderField.activeFocus) Qt.callLater(function() { folderField.forceActiveFocus() })
  }
  onConfigChanged: configUpdated()

  function reset() {
    mode = "list"
    query = ""
    addSelected = 0
    message = ""
    confirmUninstall = false
    if (empty) folderField.forceActiveFocus()
    else keyCatcher.forceActiveFocus()
  }

  function setColor(n, color) {
    var c = Model.hexOf(color)
    if (!c) { say("Colors look like #1a3a5a", true); return }
    request(["color", String(n), c])
  }

  function stepColor(step) {
    if (!current) return
    setColor(current.n, Model.stepColor(palette, current.color, step))
  }

  function move(step) {
    if (!current) return
    var target = selected + step
    if (target < 0 || target >= projects.length) return
    request(["move", String(current.n), step < 0 ? "up" : "down"])
    selected = target
  }

  function removeSelected() {
    if (!current) return
    undo = { n: current.n, path: current.path, color: current.color }
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
    Qt.callLater(function() { folderField.forceActiveFocus() })
  }

  function addFolder(path) {
    if (!path) return
    var taken = Model.projectNumber(projects, path)
    if (taken) { say(path + " is already project " + taken, true); return }
    request(["add", path, Model.freeColor(palette, projects, String(themeText), String(themeBackground))])
    selectAfterRefresh = projects.length
    mode = "list"
    query = ""
    keyCatcher.forceActiveFocus()
  }

  function addHighlighted() {
    var row = rows[addSelected]
    if (row) addFolder(row.path)
    else if (Model.isPathQuery(query)) addFolder(query)
  }

  function completeHighlighted() {
    var row = rows[addSelected]
    if (!row) return
    query = row.path === "~" ? "~/" : row.path + "/"
    folderField.text = query
    folderField.cursorPosition = query.length
  }

  function startHex() {
    if (current) mode = "hex"
  }

  function applyHex(value) {
    var c = Model.hexOf(value)
    if (!c) { say("Type a color like #1a3a5a", true); return }
    setColor(current.n, c)
    mode = "list"
    keyCatcher.forceActiveFocus()
  }

  function cancelMode() {
    mode = "list"
    query = ""
    keyCatcher.forceActiveFocus()
  }

  function install() { request(["integration", "install", "--yes"]) }

  function uninstall() {
    if (!confirmUninstall) {
      confirmUninstall = true
      say("Press Ctrl+U again to remove the plugin's lines from ~/.bashrc, hyprland.lua and the menu.", false)
      return
    }
    confirmUninstall = false
    request(["integration", "uninstall", "--yes"])
  }

  function toggleReplace() {
    request(["set", "replace-group-keys", config.replaceGroupKeys ? "no" : "yes"])
  }

  // Letter keys by position too, so they work on any keyboard layout
  // (xkb keycodes: A 38, G 42, H 43, I 31, U 30, Z 52).
  readonly property var scanCodes: ({ A: 38, G: 42, H: 43, I: 31, U: 30, Z: 52 })
  function letter(event, name) {
    return event.key === Qt["Key_" + name] || event.nativeScanCode === scanCodes[name]
  }

  function handleListKey(event) {
    var shift = event.modifiers & Qt.ShiftModifier
    var ctrl = event.modifiers & Qt.ControlModifier
    var changes = event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Delete
      || event.key === Qt.Key_Backspace || ((event.key === Qt.Key_Up || event.key === Qt.Key_Down) && shift)
    if (busy && changes) return true
    if (!letter(event, "U")) confirmUninstall = false

    if (event.key === Qt.Key_Escape) closeRequested()
    else if (event.key === Qt.Key_Up && shift) move(-1)
    else if (event.key === Qt.Key_Down && shift) move(1)
    else if (event.key === Qt.Key_Up) selected = Math.max(0, selected - 1)
    else if (event.key === Qt.Key_Down) selected = Math.min(projects.length, selected + 1)
    else if (event.key === Qt.Key_Left) stepColor(-1)
    else if (event.key === Qt.Key_Right) stepColor(1)
    else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) removeSelected()
    else if (letter(event, "Z") && ctrl) undoRemove()
    else if (letter(event, "U") && ctrl && installed) uninstall()
    else if (letter(event, "I") && !ctrl && !installed && projects.length) install()
    else if (letter(event, "G") && !ctrl && conflicts.length) toggleReplace()
    else if ((letter(event, "A") && !ctrl) || event.key === Qt.Key_Plus || event.key === Qt.Key_Insert) startAdd()
    else if (event.text === "#" || (letter(event, "H") && !ctrl)) startHex()
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (current) openProject(current.n)
      else startAdd()
    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !ctrl) {
      selected = Math.min(projects.length, event.key - Qt.Key_1)
    } else return false
    return true
  }

  // --------------------------------------------------------------- layout

  Item {
    id: keyCatcher
    focus: true
    Keys.onPressed: function(event) {
      if (root.mode === "list" && !root.empty) event.accepted = root.handleListKey(event)
    }
  }

  Column {
    id: layout
    width: parent.width
    spacing: root.gap

    // Header
    Column {
      width: parent.width
      spacing: Style.spacing.xs
      Text {
        textFormat: Text.PlainText
        text: "Colorful Terminals"
        color: root.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        font.bold: true
      }
      Text {
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.empty
          ? "Give each project its own terminal color. Pick a folder to start."
          : "Terminals in a project folder get its color. Super+Alt+N opens project N."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    // Light theme warning
    Notice {
      view: root
      visible: root.lightTheme
      tone: root.urgent
      title: "Your theme is light"
      body: "These colors are made for dark themes. Text may be hard to read until you switch to a dark theme."
    }

    // One-time setup: shows exactly what will be added before anything changes.
    Notice {
      view: root
      visible: root.loaded && !root.installed && root.projects.length > 0
      tone: root.accent
      title: "Last step: turn it on"
      body: "This adds a marked block to three files. A backup is made first, and Ctrl+U removes it later."
      detail: root.preview
      action: "Install  (I)"
      onActivated: root.install()
    }

    // Other Super+Alt+digit keys
    Notice {
      view: root
      visible: root.conflicts.length > 0 || (root.config.replaceGroupKeys && root.installed)
      tone: root.urgent
      title: root.conflicts.length
        ? "Super+Alt+" + Model.digitRange(root.conflicts.map(function(c) { return c.digit })) + " also do something else"
        : "Project keys replace Omarchy's Super+Alt+digit keys"
      body: {
        var lines = []
        for (var i = 0; i < root.conflicts.length && i < 4; i++) {
          var c = root.conflicts[i]
          lines.push("Super+Alt+" + c.digit + ": " + Model.plain(c.description, 60)
            + (c.byCode ? "" : "  (set in your own config; change it in ~/.config/hypr/bindings.lua)"))
        }
        if (root.conflicts.length > 4) lines.push("…and " + (root.conflicts.length - 4) + " more")
        return lines.join("\n")
      }
      checkLabel: "Let project keys replace them  (G)"
      checked: !!root.config.replaceGroupKeys
      showCheck: true
      onToggled: root.toggleReplace()
    }

    // Lines the helper could not read
    Notice {
      view: root
      visible: (root.config.problems || []).length > 0
      tone: root.urgent
      title: "Some lines in " + (root.config.file || "projects.conf") + " were skipped"
      body: {
        var p = root.config.problems || []
        var lines = []
        for (var i = 0; i < p.length && i < 3; i++) lines.push("Line " + p[i].line + ": " + Model.plain(p[i].text, 70))
        lines.push("A project line is a folder and a color, like  ~/code/shop  #1a3a5a")
        return lines.join("\n")
      }
    }

    // Project list
    Flickable {
      id: listFlick
      visible: !root.empty
      width: parent.width
      height: Math.min(listColumn.implicitHeight, root.maxListHeight)
      contentHeight: listColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: listColumn
        width: parent.width
        spacing: Style.spacing.xs

        Repeater {
          model: root.projects
          delegate: ProjectRow {
            required property var modelData
            required property int index
            width: listColumn.width
            view: root
            project: modelData
            isSelected: root.selected === index && root.mode !== "add"
            onClicked: { root.selected = index; root.cancelMode() }
            onYChanged: if (isSelected) root.ensureVisible(y, height)
            onHeightChanged: if (isSelected) root.ensureVisible(y, height)
            onIsSelectedChanged: if (isSelected) root.ensureVisible(y, height)
          }
        }

        // "Add project" row
        Rectangle {
          width: listColumn.width
          height: root.rowHeight * 0.8
          radius: Style.cornerRadius
          visible: root.mode !== "add"
          color: root.selected === root.projects.length ? Color.menu.selectedBackground : "transparent"
          border.color: root.faint
          border.width: 1
          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            x: root.pad
            text: "+  Add project"
            color: root.selected === root.projects.length ? Color.menu.selectedText : root.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.pad
            text: "A"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.startAdd()
          }
        }
      }
    }

    // Add project: a folder field with suggestions
    Column {
      visible: root.adding
      width: parent.width
      spacing: Style.spacing.sm

      Text {
        visible: root.empty
        textFormat: Text.PlainText
        text: "No projects yet"
        color: root.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      TextField {
        id: folderField
        width: parent.width
        placeholderText: "Type a folder, like ~/code/shop, or pick one below"
        font.family: root.fontFamily
        onTextChanged: {
          root.query = text
          root.addSelected = 0
          if (Model.isPathQuery(text)) root.queryDirs(text)
        }
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (text) text = ""
            else if (root.empty) root.closeRequested()
            else root.cancelMode()
          } else if (event.key === Qt.Key_Down) {
            root.addSelected = Math.min(root.rows.length - 1, root.addSelected + 1)
          } else if (event.key === Qt.Key_Up) {
            root.addSelected = Math.max(0, root.addSelected - 1)
          } else if (event.key === Qt.Key_Tab) {
            root.completeHighlighted()
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.addHighlighted()
          } else return
          event.accepted = true
        }
      }

      Flickable {
        id: suggestFlick
        width: parent.width
        height: Math.min(suggestColumn.implicitHeight, root.rowHeight * 0.72 * 7)
        contentHeight: suggestColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: suggestColumn
          width: parent.width

          Repeater {
            model: root.rows
            delegate: Rectangle {
              id: suggestion
              required property var modelData
              required property int index
              readonly property bool hot: root.addSelected === index
              readonly property bool primary: modelData.label === "Add current folder"
              width: suggestColumn.width
              height: root.rowHeight * (primary ? 0.9 : 0.72)
              radius: Style.cornerRadius
              // "Add current folder" is drawn as the panel's main button.
              color: primary ? (hot ? root.accent : Util.alpha(root.accent, 0.25))
                             : (hot ? Color.menu.selectedBackground : "transparent")
              onHotChanged: if (hot) {
                if (y < suggestFlick.contentY) suggestFlick.contentY = y
                else if (y + height > suggestFlick.contentY + suggestFlick.height) suggestFlick.contentY = y + height - suggestFlick.height
              }

              Text {
                id: suggestLabel
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                x: root.pad
                width: parent.width * 0.62
                elide: Text.ElideMiddle
                text: Model.plain(suggestion.modelData.label, 120)
                color: suggestion.primary && suggestion.hot ? root.themeBackground
                  : (suggestion.hot ? Color.menu.selectedText : root.text)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: suggestion.primary
              }
              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: root.pad
                width: parent.width * 0.34
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideMiddle
                text: suggestion.modelData.taken
                  ? "already project " + suggestion.modelData.taken
                  : (suggestion.primary ? Model.plain(suggestion.modelData.detail, 80) : suggestion.modelData.detail)
                color: suggestion.primary && suggestion.hot ? root.themeBackground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: root.addSelected = suggestion.index
                onClicked: root.addFolder(suggestion.modelData.path)
              }
            }
          }
        }
      }

      Text {
        visible: root.rows.length === 0
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.query
          ? "No matching repositories. Type a path that starts with ~/ or /"
          : "Type a folder path that starts with ~/ or /"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    // Status message
    Text {
      visible: root.message !== ""
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WordWrap
      text: root.message
      color: root.messageIsError ? root.urgent : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Rectangle { width: parent.width; height: 1; color: root.faint }

    // Key hints for the current mode
    Flow {
      width: parent.width
      spacing: Style.spacing.lg
      Repeater {
        model: {
          if (root.mode === "hex") return [["Enter", "apply"], ["Esc", "cancel"]]
          if (root.adding) return [["↑↓", "choose"], ["Tab", "complete"], ["Enter", "add"], ["Esc", root.empty ? "close" : "back"]]
          var hints = [["↑↓", "select"], ["←→", "color"], ["Shift+↑↓", "reorder"], ["#", "custom color"],
                       ["Enter", "open"], ["Del", "remove"], ["A", "add"]]
          if (root.undo) hints.push(["Ctrl+Z", "undo"])
          if (root.installed) hints.push(["Ctrl+U", "uninstall integration"])
          hints.push(["Esc", "close"])
          return hints
        }
        delegate: Row {
          required property var modelData
          spacing: Style.spacing.sm
          Rectangle {
            width: keyText.implicitWidth + Style.spacing.md * 2
            height: keyText.implicitHeight + Style.spacing.xs * 2
            radius: Style.cornerRadius
            color: root.faint
            Text {
              id: keyText
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: modelData[0]
              color: root.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: modelData[1]
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  function ensureVisible(y, h) {
    if (y < listFlick.contentY) listFlick.contentY = y
    else if (y + h > listFlick.contentY + listFlick.height) listFlick.contentY = y + h - listFlick.height
  }

}
