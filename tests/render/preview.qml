import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Builds preview.png (1600x900): three project terminals and the real
// settings panel. Run by tests/render-preview.
ShellRoot {
  id: test
  readonly property string outFile: Quickshell.env("CT_PREVIEW_FILE")
  readonly property var palette: [
    { name: "Blue", color: "#1a3a5a" }, { name: "Green", color: "#213f12" }, { name: "Red", color: "#681e1e" },
    { name: "Violet", color: "#4c2276" }, { name: "Plum", color: "#621d4b" }, { name: "Brown", color: "#4c3316" },
    { name: "Indigo", color: "#262e82" }, { name: "Jade", color: "#13402a" }
  ]
  readonly property var terminals: [
    { key: 1, name: "shop", path: "~/code/shop", color: "#1a3a5a", lines: ["git status", "On branch main", "nothing to commit, working tree clean"] },
    { key: 2, name: "blog", path: "~/code/blog", color: "#213f12", lines: ["npm run dev", "  ready in 412 ms", "  ➜  Local: http://localhost:5173/"] },
    { key: 3, name: "api-gateway", path: "~/work/api-gateway", color: "#681e1e", lines: ["ssh deploy@prod-1", "Last login: Fri Sep 25 18:02", "deploy@prod-1:~$ tail -f app.log"] }
  ]

  FloatingWindow {
    visible: true
    implicitWidth: 1600
    implicitHeight: 900
    color: Color.background

    Rectangle {
      id: scene
      width: 1600
      height: 900
      color: Color.background

      Text {
        x: 64; y: 50
        textFormat: Text.PlainText
        text: "Colorful Terminals"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: 40
        font.bold: true
      }
      Text {
        x: 64; y: 104
        textFormat: Text.PlainText
        text: "Every project gets its own terminal color. Super+Alt+1…9 opens it."
        color: Util.alpha(Color.foreground, 0.7)
        font.family: Style.font.family
        font.pixelSize: 20
      }

      Column {
        x: 64; y: 170
        spacing: 26
        Repeater {
          model: test.terminals
          delegate: Rectangle {
            required property var modelData
            width: 700
            height: 200
            radius: 10
            color: modelData.color
            border.color: Util.alpha(Color.foreground, 0.18)
            border.width: 1
            Rectangle {
              x: 540; y: 14
              width: keyLabel.implicitWidth + 20
              height: keyLabel.implicitHeight + 10
              radius: 6
              color: Util.alpha("#000000", 0.28)
              Text {
                id: keyLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "Super+Alt+" + modelData.key
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: 16
              }
            }
            Column {
              x: 22; y: 22
              spacing: 8
              Text {
                textFormat: Text.PlainText
                text: modelData.path + " $ " + modelData.lines[0]
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: 20
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.lines[1]
                color: Util.alpha(Color.foreground, 0.8)
                font.family: Style.font.family
                font.pixelSize: 20
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.lines[2]
                color: Util.alpha(Color.foreground, 0.8)
                font.family: Style.font.family
                font.pixelSize: 20
              }
              Row {
                Text {
                  textFormat: Text.PlainText
                  text: modelData.path + " $ "
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: 20
                }
                Rectangle { width: 11; height: 22; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
              }
            }
          }
        }
      }

      // The real settings panel, in the card PanelSurface draws, scaled up.
      BorderSurface {
        id: card
        x: 820; y: 170
        width: 470
        height: view.implicitHeight + contentTopInset + contentBottomInset
        scale: 1.5
        transformOrigin: Item.TopLeft
        radius: Style.cornerRadius
        color: Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
        padding: Style.spacing.panelPadding
        ProjectsView {
          id: view
          x: card.contentLeftInset
          y: card.contentTopInset
          width: card.width - card.contentLeftInset - card.contentRightInset
          loaded: true
          config: ({
            projects: [
              { n: 1, path: "~/code/shop", color: "#1a3a5a", name: "shop", exists: true },
              { n: 2, path: "~/code/blog", color: "#213f12", name: "blog", exists: true },
              { n: 3, path: "~/work/api-gateway", color: "#681e1e", name: "api-gateway", exists: true }
            ],
            palette: test.palette, problems: [], integration: { installed: true }, replaceGroupKeys: false
          })
          scan: ({ currentDir: "", repos: [], conflicts: [] })
          Component.onCompleted: Qt.callLater(function() { view.selected = 2 })
        }
      }
    }
  }

  Timer {
    interval: 1200
    running: true
    onTriggered: scene.grabToImage(function(result) {
      console.log(result.saveToFile(test.outFile) ? "PASS: preview saved" : "FAIL: preview not saved")
      Qt.quit()
    })
  }
}
