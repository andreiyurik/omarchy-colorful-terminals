import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Picking a folder: a search field over git repositories, or a path with
// completion. It is the whole panel when there are no projects yet.
Column {
  id: add

  property var view
  readonly property int rowHeight: Math.max(Style.space(34), Style.font.body + Style.spacing.rowPaddingX * 2)

  function focusField() { field.forceActiveFocus() }
  function setText(value) {
    field.text = value
    field.cursorPosition = value.length
  }

  spacing: Style.space(10)

  Text {
    visible: add.view.empty
    textFormat: Text.PlainText
    width: parent.width
    wrapMode: Text.WordWrap
    text: "Pick a folder. Its terminals get their own color, and Super+Ctrl+Alt+1 opens it."
    color: add.view.text
    font.family: add.view.fontFamily
    font.pixelSize: Style.font.body
  }

  PanelSectionHeader {
    visible: !add.view.empty
    text: "ADD PROJECT"
    foreground: add.view.text
    fontFamily: add.view.fontFamily
  }

  TextField {
    id: field
    width: parent.width
    placeholderText: "Search repositories or type ~/path…"
    font.family: add.view.fontFamily
    foreground: add.view.text
    accent: add.view.accent
    onTextChanged: {
      add.view.query = text
      add.view.addSelected = 0
      var q = Model.folderQuery(text)
      if (Model.isPathQuery(q)) add.view.queryDirs(q)
    }
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        if (text) text = ""
        else if (add.view.empty) add.view.closeRequested()
        else add.view.cancelMode()
      } else if (event.key === Qt.Key_Down) {
        add.view.addSelected = Math.min(add.view.rows.length - 1, add.view.addSelected + 1)
        pointerGate.reset()
      } else if (event.key === Qt.Key_Up) {
        add.view.addSelected = Math.max(0, add.view.addSelected - 1)
        pointerGate.reset()
      } else if (event.key === Qt.Key_Tab) {
        add.view.completeHighlighted()
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        add.view.addHighlighted()
      } else return
      event.accepted = true
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: add
  }

  Flickable {
    id: list
    visible: add.view.rows.length > 0
    width: parent.width
    height: Math.min(listColumn.implicitHeight, add.rowHeight * 7)
    contentHeight: listColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: listColumn
      width: parent.width
      spacing: Style.spacing.xs

      Repeater {
        model: add.view.rows
        delegate: CursorSurface {
          id: suggestion
          required property var modelData
          required property int index
          width: listColumn.width
          height: add.rowHeight
          hasCursor: add.view.addSelected === index
          foreground: add.view.text
          accent: add.view.accent
          onHasCursorChanged: if (hasCursor) {
            if (y < list.contentY) list.contentY = y
            else if (y + height > list.contentY + list.height) list.contentY = y + height - list.height
          }

          Text {
            id: suggestionName
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            x: Style.space(10)
            width: Math.min(implicitWidth, parent.width * 0.6)
            elide: Text.ElideMiddle
            text: Model.plain(suggestion.modelData.name, 80)
            color: suggestion.hasCursor ? Commons.Color.menu.selectedText : add.view.text
            font.family: add.view.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: suggestionName.right
            anchors.leftMargin: Style.space(10)
            anchors.right: note.left
            anchors.rightMargin: Style.space(10)
            elide: Text.ElideMiddle
            text: Model.plain(suggestion.modelData.parent, 160)
            color: add.view.dim
            font.family: add.view.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            id: note
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            text: suggestion.modelData.taken ? "already project " + suggestion.modelData.taken
              : suggestion.modelData.note
            color: add.view.dim
            font.family: add.view.fontFamily
            font.pixelSize: Style.font.caption
          }
          MouseArea {
            id: suggestionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) {
              if (pointerGate.moved(suggestionMouse, mouse)) add.view.addSelected = suggestion.index
            }
            onClicked: add.view.addFolder(suggestion.modelData.path)
          }
        }
      }
    }
  }

  Text {
    visible: add.view.rows.length === 0
    textFormat: Text.PlainText
    width: parent.width
    wrapMode: Text.WordWrap
    text: add.view.query
      ? "No matching repositories. Type a path that starts with ~/ or /"
      : "Type a folder path that starts with ~/ or /"
    color: add.view.dim
    font.family: add.view.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
