import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// One project: a tile in its color with its key digit, the folder name, and
// the folder it sits in. The row under the cursor opens up to show the
// palette and its move and remove buttons.
CursorSurface {
  id: row

  property var view
  required property int index
  required property int n
  required property string name
  required property string path
  required property string tint
  required property bool exists

  readonly property bool expanded: hasCursor && view.mode !== "add"
  readonly property bool editingHex: expanded && view.mode === "hex"
  // While a custom color is typed, the tile previews it.
  readonly property string shown: editingHex && view.hexPreview !== "" ? view.hexPreview : tint
  readonly property string issue: Model.colorIssue(shown, String(view.themeText), String(view.themeBackground))
  readonly property bool custom: Model.paletteIndex(view.palette, shown) < 0

  signal pointed(var item, var mouse)
  signal picked()

  foreground: view.text
  accent: view.accent
  implicitHeight: content.implicitHeight + Style.spacing.rowPaddingX
  height: implicitHeight

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    onPositionChanged: function(mouse) { row.pointed(rowMouse, mouse) }
    onClicked: row.picked()
    onDoubleClicked: if (row.exists) row.view.openProject(row.n)
  }

  Item {
    id: content
    x: Style.space(10)
    y: Style.spacing.rowPaddingX / 2
    width: parent.width - Style.space(20)
    implicitHeight: top.height + paletteArea.height

    Item {
      id: top
      width: parent.width
      height: Math.max(tile.height, labels.implicitHeight)

      // The project color with its key, in the theme's text color: the same
      // pair a terminal shows, so a hard-to-read color is visible here.
      Rectangle {
        id: tile
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(32)
        height: width
        radius: Style.cornerRadius
        color: row.exists ? row.shown : Util.alpha(row.view.text, 0.06)
        border.color: Util.alpha(row.view.text, row.hasCursor ? 0.4 : 0.16)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: row.n <= 9 ? String(row.n) : "·"
          color: row.exists ? row.view.themeText : Util.alpha(row.view.text, 0.45)
          font.family: row.view.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Rectangle {
          visible: row.exists && row.issue !== ""
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(3)
          width: Style.space(6)
          height: width
          radius: width / 2
          color: row.view.urgent
        }
      }

      Column {
        id: labels
        anchors.left: tile.right
        anchors.leftMargin: Style.space(12)
        anchors.right: actions.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          elide: Text.ElideRight
          text: Model.plain(row.name, 80)
          color: row.exists ? row.view.text : row.view.dim
          font.family: row.view.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          elide: Text.ElideMiddle
          text: row.exists
            ? Model.plain(Model.rowSubtitle(row.n, row.path), 180)
            : "Folder not found · " + Model.plain(row.path, 160)
          color: row.exists ? row.view.dim : row.view.urgent
          font.family: row.view.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        opacity: row.expanded ? 1 : 0
        enabled: row.expanded
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        PanelActionButton {
          iconText: "󰁝"
          tooltipText: "Move up · Shift+↑" + (row.n > 1 && row.n - 1 <= Model.MAX_KEYS ? " · becomes " + Model.keyLabel(row.n - 1) : "")
          foreground: row.view.text
          fontFamily: row.view.fontFamily
          enabled: row.expanded && row.index > 0
          onClicked: row.view.move(-1)
        }
        PanelActionButton {
          iconText: "󰁅"
          tooltipText: "Move down · Shift+↓" + (row.n + 1 <= Model.MAX_KEYS ? " · becomes " + Model.keyLabel(row.n + 1) : " · no key")
          foreground: row.view.text
          fontFamily: row.view.fontFamily
          enabled: row.expanded && row.index < row.view.projects.length - 1
          onClicked: row.view.move(1)
        }
        PanelActionButton {
          iconText: "󰆴"
          tooltipText: "Remove · Del"
          foreground: row.view.text
          hoverColor: row.view.urgent
          fontFamily: row.view.fontFamily
          onClicked: row.view.removeSelected()
        }
      }
    }

    // Palette, custom color, and the color's name or problem.
    Item {
      id: paletteArea
      anchors.top: top.bottom
      width: parent.width
      readonly property bool shown: row.expanded && row.exists
      height: shown ? swatches.height + Style.space(10) : 0
      opacity: shown ? 1 : 0
      clip: true

      Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      Row {
        id: swatches
        y: Style.space(8)
        x: tile.width + Style.space(12) - Style.space(4)
        spacing: Style.space(2)

        Repeater {
          model: row.view.palette
          delegate: Swatch {
            required property var modelData
            view: row.view
            fill: modelData.color
            label: modelData.name
            current: Model.hexOf(modelData.color) === Model.hexOf(row.shown)
            onChosen: row.view.setColor(row.n, modelData.color)
          }
        }

        // Custom color: shows the color once one is set, "#" until then.
        Swatch {
          view: row.view
          fill: row.custom ? row.shown : "transparent"
          glyph: row.custom ? "" : "#"
          label: "Custom color · C"
          current: row.custom || row.editingHex
          onChosen: row.view.startHex()
        }

        Item { width: Style.space(8); height: 1 }

        Text {
          visible: !row.editingHex
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, paletteArea.width - x - Style.space(4))
          elide: Text.ElideRight
          text: row.issue !== "" ? row.issue : Model.colorName(row.view.palette, row.shown)
          color: row.issue !== "" ? row.view.urgent : row.view.dim
          font.family: row.view.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        TextField {
          id: hexField
          visible: row.editingHex
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(92)
          verticalPadding: Style.spacing.xs
          maximumLength: 7
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          foreground: row.view.text
          accent: row.view.accent
          onVisibleChanged: if (visible) {
            text = row.tint
            forceActiveFocus()
            selectAll()
          }
          onTextChanged: if (visible) row.view.hexPreview = Model.hexOf(text)
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) row.view.cancelMode()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) row.view.applyHex(text)
            else return
            event.accepted = true
          }
        }

        Text {
          visible: row.editingHex
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: Style.space(8)
          text: row.view.hexPreview === "" ? "Like #003b63" : row.issue
          color: row.view.hexPreview === "" ? row.view.dim : row.view.urgent
          font.family: row.view.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
