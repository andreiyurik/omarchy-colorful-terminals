import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// The panel window: a dimmed full-screen layer with the settings card in the
// middle. Loaded by Panel.qml only while the panel is open.
PanelWindow {
  id: panel

  property var controller: null

  visible: true
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  WlrLayershell.namespace: "omarchy-colorful-terminals"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  exclusionMode: ExclusionMode.Ignore

  Rectangle {
    anchors.fill: parent
    color: Color.menu.scrim
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (panel.controller) panel.controller.dismiss()
  }

  BorderSurface {
    id: card
    width: Math.min(Style.space(680), panel.width - Style.gapsOut * 4)
    height: Math.min(view.implicitHeight + contentTopInset + contentBottomInset, panel.height - Style.gapsOut * 4)
    anchors.centerIn: parent
    radius: Style.cornerRadius
    color: Color.menu.background
    borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
    padding: Style.spacing.panelPadding

    MouseArea { anchors.fill: parent; onClicked: {} }

    ProjectsView {
      id: view
      x: card.contentLeftInset
      y: card.contentTopInset
      width: card.width - card.contentLeftInset - card.contentRightInset
      maxListHeight: panel.height * 0.5

      loaded: !!(panel.controller && panel.controller.config)
      config: (panel.controller && panel.controller.config)
        || ({ projects: [], palette: [], problems: [], integration: { installed: true }, replaceGroupKeys: false })
      scan: panel.controller ? panel.controller.scan : ({ currentDir: "", repos: [], conflicts: [] })
      dirs: panel.controller ? panel.controller.dirs : []
      preview: panel.controller ? panel.controller.preview : ""

      onRun: function(args) { panel.controller.change(args) }
      onOpenProject: function(n) { panel.controller.openProject(n) }
      onCloseRequested: panel.controller.dismiss()
      onQueryDirs: function(path) { panel.controller.queryDirs(path) }

      Component.onCompleted: Qt.callLater(function() {
        view.reset()
        view.forceActiveFocus()
      })
    }

    Connections {
      target: panel.controller
      function onCommandFinished(args, ok, out, err) { view.finished(args, ok, out, err) }
      function onChangeSettled() { view.settled() }
    }
  }
}
