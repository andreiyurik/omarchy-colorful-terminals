import QtQuick
import qs.Commons
import qs.Ui

// The one-time setup: what turning it on changes, in plain words, with the
// exact lines one click away. Nothing changes until "Turn on".
Column {
  id: setup

  property var view

  spacing: Style.space(10)

  PanelSectionHeader {
    text: "TURN IT ON"
    foreground: setup.view.text
    fontFamily: setup.view.fontFamily
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    wrapMode: Text.WordWrap
    text: "This adds a marked block to each file below. A backup of each is saved first, and Turn off takes the blocks out again."
    color: setup.view.dim
    font.family: setup.view.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Grid {
    columns: 2
    columnSpacing: Style.space(16)
    rowSpacing: Style.spacing.xs
    leftPadding: Style.space(10)

    Repeater {
      // Pairs of file and purpose, from the helper: bash always, zsh and fish
      // when this system uses them, then Hyprland and the menu.
      model: {
        var files = (setup.view.config.integration && setup.view.config.integration.files) || []
        var out = []
        for (var i = 0; i < files.length; i++) out.push(files[i].file, files[i].what)
        return out
      }
      delegate: Text {
        required property var modelData
        required property int index
        readonly property bool file: index % 2 === 0
        textFormat: Text.PlainText
        text: modelData
        color: file ? setup.view.text : setup.view.dim
        font.family: file ? Style.font.family : setup.view.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Toggle {
    visible: setup.view.conflicts.length > 0
    width: parent.width
    label: setup.view.keysLabel
    description: setup.view.keysDescription(setup.view.setupReplace)
    checked: setup.view.setupReplace
    hasCursor: setup.view.target === "setupKeys"
    foreground: setup.view.text
    accent: setup.view.accent
    fontFamily: setup.view.fontFamily
    onClicked: setup.view.setupReplace = !setup.view.setupReplace
    onHovered: function(on) { if (on) setup.view.pointAt("setupKeys") }
  }

  Row {
    spacing: Style.spacing.controlGap

    Button {
      text: "Turn on"
      bordered: true
      hasCursor: setup.view.target === "install"
      foreground: setup.view.text
      accent: setup.view.accent
      fontFamily: setup.view.fontFamily
      onClicked: setup.view.install()
      onHovered: function(on) { if (on) setup.view.pointAt("install") }
    }
    Button {
      text: setup.view.showLines ? "Hide exact lines" : "Show exact lines"
      foreground: setup.view.dim
      fontFamily: setup.view.fontFamily
      onClicked: setup.view.showLines = !setup.view.showLines
    }
  }

  Flickable {
    visible: setup.view.showLines
    width: parent.width
    height: Math.min(lines.implicitHeight, Style.space(170))
    contentHeight: lines.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Text {
      id: lines
      width: parent.width
      textFormat: Text.PlainText
      wrapMode: Text.WrapAnywhere
      text: setup.view.preview
      color: setup.view.dim
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
}
