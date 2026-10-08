import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The color keys: Super+Ctrl+Alt+Shift+1…8 give the terminal you are in a
// color of its own, and +0 takes it away. A tile per key in its color, like
// the project tiles; the key under the cursor opens up to show the palette.
Column {
  id: keys

  property var view

  readonly property bool expanded: surface.hasCursor
  readonly property int slot: view.paintSlot
  readonly property bool editingHex: expanded && view.mode === "hex"
  readonly property string color: view.paintColors[slot - 1] || ""
  // While a custom color is typed, the tile previews it.
  readonly property string shown: editingHex && view.hexPreview !== "" ? view.hexPreview : color
  readonly property string issue: Model.colorIssue(shown, String(view.themeText), String(view.themeBackground))
  readonly property bool custom: Model.paletteIndex(view.palette, shown) < 0
  readonly property string standard: view.palette[slot - 1] ? Model.hexOf(view.palette[slot - 1].color) : ""

  spacing: Style.spacing.xs

  Item {
    width: parent.width
    height: Math.max(sectionTitle.implicitHeight, keyName.implicitHeight)

    PanelSectionHeader {
      id: sectionTitle
      x: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: "Any terminal"
      foreground: keys.view.text
      fontFamily: keys.view.fontFamily
    }
    Text {
      id: keyName
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "Super+Ctrl+Alt+Shift + digit"
      color: keys.view.dim
      font.family: keys.view.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  CursorSurface {
    id: surface
    width: parent.width
    hasCursor: keys.view.target === "paint"
    foreground: keys.view.text
    accent: keys.view.accent
    implicitHeight: content.implicitHeight + Style.spacing.rowPaddingX
    height: implicitHeight

    MouseArea {
      id: surfaceMouse
      anchors.fill: parent
      hoverEnabled: true
      onPositionChanged: function(mouse) { keys.view.pointRow(keys.view.targets.indexOf("paint"), surfaceMouse, mouse) }
    }

    Column {
      id: content
      x: Style.space(10)
      y: Style.spacing.rowPaddingX / 2
      width: parent.width - Style.space(20)
      spacing: Style.space(8)

      Row {
        id: tiles
        spacing: Style.space(6)

        Repeater {
          model: 8
          delegate: Rectangle {
            id: tile
            required property int index
            readonly property int n: index + 1
            readonly property bool chosen: keys.expanded && keys.slot === n
            readonly property string fill: chosen ? keys.shown : (keys.view.paintColors[index] || "transparent")

            width: Style.space(32)
            height: width
            radius: Style.cornerRadius
            color: fill
            border.color: chosen ? keys.view.accent : Util.alpha(keys.view.text, keys.expanded ? 0.4 : 0.16)
            border.width: chosen ? Math.max(2, Style.space(2)) : 1

            Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: String(tile.n)
              color: keys.view.themeText
              font.family: keys.view.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Rectangle {
              visible: Model.colorIssue(tile.fill, String(keys.view.themeText), String(keys.view.themeBackground)) !== ""
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(3)
              width: Style.space(6)
              height: width
              radius: width / 2
              color: keys.view.urgent
            }

            MouseArea {
              id: tileMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: keys.view.pickPaintSlot(tile.n)
            }
            PanelToolTip {
              visible: tileMouse.containsMouse && !tile.chosen
              text: "Super+Ctrl+Alt+Shift+" + tile.n + " · " + Model.colorName(keys.view.palette, tile.fill)
              fontFamily: keys.view.fontFamily
            }
          }
        }

        // 0 takes the color away: the theme's own background, dashed off.
        Rectangle {
          id: zeroTile
          width: Style.space(32)
          height: width
          radius: Style.cornerRadius
          color: "transparent"
          border.color: Util.alpha(keys.view.text, 0.25)
          border.width: 1

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: "0"
            color: keys.view.dim
            font.family: keys.view.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          MouseArea {
            id: zeroMouse
            anchors.fill: parent
            hoverEnabled: true
          }
          PanelToolTip {
            visible: zeroMouse.containsMouse
            text: "Super+Ctrl+Alt+Shift+0 · back to the project or theme color"
            fontFamily: keys.view.fontFamily
          }
        }
      }

      // What the keys do, until one is picked; then its palette.
      Text {
        visible: !keys.expanded
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: "Press one in any terminal to give it that color, even in a project. 0 takes the color away."
        color: keys.view.dim
        font.family: keys.view.fontFamily
        font.pixelSize: Style.font.caption
      }

      Row {
        id: swatches
        visible: keys.expanded
        x: -Style.space(4)
        spacing: Style.space(2)

        Repeater {
          model: keys.view.palette
          delegate: Swatch {
            required property var modelData
            view: keys.view
            fill: modelData.color
            label: modelData.name
            current: Model.hexOf(modelData.color) === Model.hexOf(keys.shown)
            onChosen: keys.view.setPaintColor(keys.slot, modelData.color)
          }
        }

        // Custom color: shows the color once one is set, "#" until then.
        Swatch {
          view: keys.view
          fill: keys.custom ? keys.shown : "transparent"
          glyph: keys.custom ? "" : "#"
          label: "Custom color · C"
          current: keys.custom || keys.editingHex
          onChosen: keys.view.startHex()
        }

        Item { width: Style.space(8); height: 1 }

        Text {
          visible: !keys.editingHex
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, content.width - x - Style.space(4))
          elide: Text.ElideRight
          text: {
            if (keys.issue !== "") return keys.issue
            var name = "Super+Ctrl+Alt+Shift+" + keys.slot + " · " + Model.colorName(keys.view.palette, keys.shown)
            if (keys.standard !== "" && Model.hexOf(keys.shown) !== keys.standard)
              name += " · Del: " + Model.colorName(keys.view.palette, keys.standard)
            return name
          }
          color: keys.issue !== "" ? keys.view.urgent : keys.view.dim
          font.family: keys.view.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        TextField {
          id: hexField
          visible: keys.editingHex
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(92)
          verticalPadding: Style.spacing.xs
          maximumLength: 7
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          foreground: keys.view.text
          accent: keys.view.accent
          onVisibleChanged: if (visible) {
            text = keys.color
            forceActiveFocus()
            selectAll()
          }
          onTextChanged: if (visible) keys.view.hexPreview = Model.hexOf(text)
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) keys.view.cancelMode()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) keys.view.applyHex(text)
            else return
            event.accepted = true
          }
        }

        Text {
          visible: keys.editingHex
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: Style.space(8)
          text: keys.view.hexPreview === "" ? "Like #003b63" : keys.issue
          color: keys.view.hexPreview === "" ? keys.view.dim : keys.view.urgent
          font.family: keys.view.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
