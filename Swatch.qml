import QtQuick
import qs.Commons
import qs.Ui

// One palette color: a dot with a faint ring so dark colors stand out on a
// dark panel, and an accent ring when it is the project's color.
Item {
  id: swatch

  property var view
  property color fill: "transparent"
  property string glyph: ""
  property string label: ""
  property bool current: false
  signal chosen()

  width: Style.space(26)
  height: width

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: "transparent"
    border.color: swatch.view.accent
    border.width: Math.max(2, Style.space(2))
    opacity: swatch.current ? 1 : (mouse.containsMouse ? 0.35 : 0)
    scale: swatch.current ? 1 : 0.82

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
  }

  Rectangle {
    anchors.centerIn: parent
    width: Style.space(18)
    height: width
    radius: width / 2
    color: swatch.fill
    border.color: Util.alpha(swatch.view.text, swatch.glyph !== "" ? 0.45 : 0.3)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 180 } }

    Text {
      visible: swatch.glyph !== ""
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: swatch.glyph
      color: swatch.view.dim
      font.family: swatch.view.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: swatch.chosen()
  }

  PanelToolTip {
    visible: mouse.containsMouse && swatch.label !== ""
    text: swatch.label
    fontFamily: swatch.view.fontFamily
  }
}
