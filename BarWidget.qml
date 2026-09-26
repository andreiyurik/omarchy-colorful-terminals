import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar icon: click to open or close the Colorful Terminals panel.
BarWidget {
  id: root
  moduleName: "andreiyurik.colorful-terminals"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏘"
    tooltipText: "Colorful Terminals: project colors and Super+Alt keys"
    onPressed: function(buttonCode) {
      Quickshell.execDetached(["omarchy-shell", "shell", "toggle", root.moduleName, "{}"])
    }
  }
}
