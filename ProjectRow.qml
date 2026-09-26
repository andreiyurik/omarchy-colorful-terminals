import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// One project: key number, folder, and a mini terminal in the project color.
// The selected row also shows the palette and the ↑ ↓ ✕ buttons.
Rectangle {
  id: row

  property var view
  property var project
  property bool isSelected: false
  signal clicked()

  readonly property string issue: Model.colorIssue(project.color, String(view.themeText), String(view.themeBackground))
  readonly property bool editingHex: isSelected && view.mode === "hex"

  height: content.implicitHeight + view.pad
  radius: Style.cornerRadius
  color: isSelected ? Color.menu.selectedBackground : "transparent"
  border.color: isSelected ? Util.alpha(view.accent, 0.5) : "transparent"
  border.width: 1

  MouseArea {
    anchors.fill: parent
    onClicked: row.clicked()
  }

  Column {
    id: content
    x: row.view.pad
    y: row.view.pad / 2
    width: parent.width - row.view.pad * 2
    spacing: Style.spacing.md

    Item {
      width: parent.width
      height: Math.max(info.implicitHeight, terminal.height)

      // Key number
      Rectangle {
        id: badge
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(26)
        height: width
        radius: Style.cornerRadius
        color: row.project.n <= 9 ? Util.alpha(row.view.text, 0.10) : "transparent"
        border.color: row.view.faint
        border.width: 1
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: row.project.n <= 9 ? String(row.project.n) : "–"
          color: row.isSelected ? Color.menu.selectedText : row.view.text
          font.family: row.view.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }

      // Folder name and path
      Column {
        id: info
        anchors.left: badge.right
        anchors.leftMargin: row.view.pad
        anchors.right: terminal.left
        anchors.rightMargin: row.view.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.xxs
        Text {
          textFormat: Text.PlainText
          width: parent.width
          elide: Text.ElideRight
          text: Model.plain(row.project.name, 80)
          color: row.isSelected ? Color.menu.selectedText : row.view.text
          font.family: row.view.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Row {
          width: parent.width
          spacing: Style.spacing.lg
          Text {
            id: keyText
            textFormat: Text.PlainText
            visible: row.project.exists
            text: Model.keyLabel(row.project.n)
            color: row.view.dim
            font.family: row.view.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width - (keyText.visible ? keyText.width + parent.spacing : 0)
            elide: Text.ElideMiddle
            text: row.project.exists
              ? Model.plain(row.project.path, 160)
              : "Folder not found: " + Model.plain(row.project.path, 160)
            color: row.project.exists ? row.view.dim : row.view.urgent
            font.family: row.view.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      // Mini terminal: project background, theme text
      Rectangle {
        id: terminal
        anchors.right: buttons.left
        anchors.rightMargin: row.view.pad / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(150)
        height: Style.space(34)
        radius: Style.cornerRadius
        color: row.project.color
        border.color: row.view.faint
        border.width: 1
        Row {
          anchors.verticalCenter: parent.verticalCenter
          x: Style.spacing.lg
          spacing: 0
          Text {
            textFormat: Text.PlainText
            text: Model.plain(row.project.name, 14) + " $ "
            color: row.view.themeText
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          Rectangle {
            width: Style.space(7)
            height: Style.font.bodySmall + 2
            anchors.verticalCenter: parent.verticalCenter
            color: row.view.themeText
            opacity: 0.85
          }
        }
        Text {
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.rightMargin: Style.spacing.md
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.spacing.xxs
          text: row.issue ? "!" : ""
          color: row.view.urgent
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }

      // Move up / down, remove
      Row {
        id: buttons
        // Always takes its space, so the mini terminals line up in every row.
        opacity: row.isSelected ? 1 : 0
        enabled: row.isSelected
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.spacing.xs
        Repeater {
          model: [["↑", "up"], ["↓", "down"], ["✕", "remove"]]
          delegate: Rectangle {
            required property var modelData
            width: Style.space(24)
            height: width
            radius: Style.cornerRadius
            color: iconMouse.containsMouse ? Util.alpha(row.view.text, 0.14) : "transparent"
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: modelData[0]
              color: row.view.text
              font.pixelSize: Style.font.body
            }
            MouseArea {
              id: iconMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData[1] === "up") row.view.move(-1)
                else if (modelData[1] === "down") row.view.move(1)
                else row.view.removeSelected()
              }
            }
          }
        }
      }
    }

    // Palette, only on the selected row
    Item {
      visible: row.isSelected
      width: parent.width
      height: visible ? Math.max(swatches.implicitHeight, hexBox.height) : 0

      Row {
        id: swatches
        anchors.verticalCenter: parent.verticalCenter
        x: badge.width + row.view.pad
        spacing: Style.spacing.md
        Repeater {
          model: row.view.palette
          delegate: Rectangle {
            required property var modelData
            readonly property bool current: Model.hexOf(modelData.color) === Model.hexOf(row.project.color)
            width: Style.space(22)
            height: width
            radius: width / 2
            color: modelData.color
            border.color: current ? row.view.text : row.view.faint
            border.width: current ? 2 : 1
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: row.view.setColor(row.project.n, modelData.color)
            }
          }
        }
      }

      // Current color name, or the custom color field
      Item {
        id: hexBox
        anchors.left: swatches.right
        anchors.leftMargin: row.view.pad
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: hexField.implicitHeight

        Text {
          visible: !row.editingHex
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          elide: Text.ElideRight
          text: row.issue
            ? row.issue
            : Model.colorName(row.view.palette, row.project.color) + "   # custom"
          color: row.issue ? row.view.urgent : row.view.dim
          font.family: row.view.fontFamily
          font.pixelSize: Style.font.bodySmall
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.view.startHex()
          }
        }

        TextField {
          id: hexField
          visible: row.editingHex
          width: Math.min(parent.width, Style.space(120))
          maximumLength: 7
          font.family: Style.font.family
          onVisibleChanged: if (visible) {
            text = row.project.color
            forceActiveFocus()
            selectAll()
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) row.view.cancelMode()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) row.view.applyHex(text)
            else return
            event.accepted = true
          }
        }
      }
    }
  }
}
