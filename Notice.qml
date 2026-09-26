import QtQuick
import qs.Commons

// A tinted box with a title, text, and an optional button or checkbox.
Rectangle {
  id: notice

  property var view
  property color tone: view.accent
  property string title: ""
  property string body: ""
  property string detail: ""
  property string action: ""
  property string checkLabel: ""
  property bool showCheck: false
  property bool checked: false
  signal activated()
  signal toggled()

  width: parent ? parent.width : 0
  height: visible ? noticeColumn.implicitHeight + view.pad * 1.4 : 0
  radius: Style.cornerRadius
  color: Util.alpha(tone, 0.10)
  border.color: Util.alpha(tone, 0.55)
  border.width: 1

  Column {
    id: noticeColumn
    x: notice.view.pad
    y: notice.view.pad * 0.7
    width: parent.width - notice.view.pad * 2
    spacing: Style.spacing.sm

    Text {
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WordWrap
      text: notice.title
      color: notice.view.text
      font.family: notice.view.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
    Text {
      visible: notice.body !== ""
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WordWrap
      text: notice.body
      color: notice.view.dim
      font.family: notice.view.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      visible: notice.detail !== ""
      textFormat: Text.PlainText
      width: parent.width
      wrapMode: Text.WrapAnywhere
      text: notice.detail
      color: notice.view.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Item {
      visible: notice.showCheck
      width: checkRow.implicitWidth
      height: checkRow.implicitHeight
      Row {
        id: checkRow
        spacing: Style.spacing.md
        Rectangle {
          width: Style.space(14)
          height: width
          radius: 2
          anchors.verticalCenter: parent.verticalCenter
          color: notice.checked ? notice.tone : "transparent"
          border.color: notice.tone
          border.width: 1
          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: notice.checked
            text: "✓"
            color: notice.view.themeBackground
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
        Text {
          textFormat: Text.PlainText
          text: notice.checkLabel
          color: notice.view.text
          font.family: notice.view.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: notice.toggled()
      }
    }
    Rectangle {
      visible: notice.action !== ""
      width: actionText.implicitWidth + notice.view.pad * 2
      height: actionText.implicitHeight + Style.spacing.md * 2
      radius: Style.cornerRadius
      color: notice.tone
      Text {
        id: actionText
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: notice.action
        color: notice.view.themeBackground
        font.family: notice.view.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: notice.activated()
      }
    }
  }
}
