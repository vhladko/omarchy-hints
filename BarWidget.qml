import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "vhladko.hints"

  property string mode: "full"
  property bool popupOpen: false
  readonly property bool opened: popupOpen

  readonly property string sourceDir: {
    var value = String(Qt.resolvedUrl("."))
    if (value.indexOf("file://") === 0)
      value = value.substring(7)
    try {
      return decodeURIComponent(value)
    } catch (error) {
      return value
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() {
    root.popupOpen = true
  }

  function close() {
    root.popupOpen = false
  }

  function toggle() {
    root.popupOpen = !root.popupOpen
  }

  function refresh() {
    read.running = true
  }

  function pick(value) {
    apply.running = false
    apply.command = ["omarchy-shell", "vhladko.hints", "setMode", value]
    apply.running = true
    root.mode = value
    root.popupOpen = false
  }

  Process {
    id: read
    command: [root.sourceDir + "/scripts/state"]
    running: false
    stdout: StdioCollector {
      id: readOut
      waitForEnd: true
    }
    onExited: {
      var value = String(readOut.text).trim()
      if (value === "full" || value === "beginner" || value === "off")
        root.mode = value
    }
  }

  Process {
    id: apply
    command: ["omarchy-shell", "vhladko.hints", "setMode", "full"]
    running: false
    stdout: StdioCollector {
      id: applyOut
      waitForEnd: true
    }
    onExited: {
      var value = String(applyOut.text).trim()
      if (value === "full" || value === "beginner" || value === "off")
        root.mode = value
    }
  }

  IpcHandler {
    target: "vhladko.hints.bar"
    function open(): void {
      root.open()
    }
    function close(): void {
      root.close()
    }
    function toggle(): void {
      root.toggle()
    }
  }

  Component.onCompleted: root.refresh()

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    dimmed: root.mode === "off"
    active: root.mode !== "off"
    useActiveColor: root.mode === "beginner"
    tooltipText: ""
    onPressed: function() {
      root.toggle()
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(160))
    contentHeight: popup.fittedContentHeight(choices.implicitHeight)

    Column {
      id: choices
      width: parent.width
      spacing: Style.space(2)

      Repeater {
        model: [
          { id: "full", label: "Full" },
          { id: "beginner", label: "Beginner" },
          { id: "off", label: "Off" }
        ]

        delegate: Rectangle {
          required property var modelData
          readonly property bool selected: root.mode === modelData.id
          width: parent.width
          height: row.implicitHeight + Style.space(10)
          radius: Style.cornerRadius
          color: selected ? Color.accent : (hover.hovered ? Style.hoverFill : "transparent")

          Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: selected ? "●" : "○"
              color: selected ? Color.background : Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              textFormat: Text.PlainText
              text: modelData.label
              color: selected ? Color.background : (root.bar ? root.bar.foreground : Color.foreground)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          HoverHandler {
            id: hover
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pick(modelData.id)
          }
        }
      }
    }
  }
}
