import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Hints.js" as Hints

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int mask: 0
  property int lastSeq: 0
  property var rows: []
  property var viewModel: ({ title: "", rows: [], columns: [] })
  property int colCount: 4
  property string mode: "full"

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

  readonly property string focusedName: {
    var monitor = Hyprland.focusedMonitor
    return monitor && monitor.name ? String(monitor.name) : ""
  }

  function rebuild() {
    root.viewModel = Hints.view(root.rows, root.mask, root.colCount, root.mode)
  }

  function accept(seq, nextMask) {
    var n = Number(seq)
    if (isFinite(n) && n > 0 && n < root.lastSeq)
      return
    if (isFinite(n) && n > 0)
      root.lastSeq = n

    root.mask = Number(nextMask) || 0
    if ((root.mask & 64) === 0 || root.mode === "off") {
      root.opened = false
      return
    }

    if (root.rows.length === 0 && !load.running)
      load.running = true

    root.maybeOpen()
  }

  function maybeOpen() {
    if ((root.mask & 64) === 0 || root.mode === "off") {
      root.opened = false
      return
    }
    if (root.rows.length === 0)
      return
    root.rebuild()
    root.opened = root.viewModel.rows.length > 0
  }

  function applyMode(value) {
    var next = String(value || "").trim()
    if (next !== "full" && next !== "beginner" && next !== "off")
      return root.mode
    root.mode = next
    writeMode.running = false
    writeMode.running = true
    if (root.mode === "off")
      root.opened = false
    else if ((root.mask & 64) !== 0)
      root.maybeOpen()
    return root.mode
  }

  function cycleMode() {
    if (root.mode === "full")
      return root.applyMode("beginner")
    if (root.mode === "beginner")
      return root.applyMode("off")
    return root.applyMode("full")
  }

  function open(payloadJson) {
    root.accept(root.lastSeq + 1, 64)
  }

  function close() {
    root.mask = 0
    root.opened = false
  }

  Process {
    id: load
    command: [root.sourceDir + "/scripts/binds"]
    running: false
    stdout: StdioCollector {
      id: loadOut
      waitForEnd: true
    }
    onExited: {
      root.rows = Hints.parse(loadOut.text)
      root.maybeOpen()
    }
  }

  Process {
    id: hook
    command: [root.sourceDir + "/scripts/on", root.sourceDir]
    running: false
  }

  Process {
    id: readMode
    command: [root.sourceDir + "/scripts/state"]
    running: false
    stdout: StdioCollector {
      id: readModeOut
      waitForEnd: true
    }
    onExited: {
      var value = String(readModeOut.text).trim()
      if (value === "full" || value === "beginner" || value === "off")
        root.mode = value
    }
  }

  Process {
    id: writeMode
    command: [root.sourceDir + "/scripts/state", root.mode]
    running: false
  }

  IpcHandler {
    target: "vhladko.hints"
    function state(sequence: int, mask: int): void {
      root.accept(sequence, mask)
    }
    function ping(): string {
      return "ok"
    }
    function mode(): string {
      return root.mode
    }
    function cycle(): string {
      return root.cycleMode()
    }
    function setMode(value: string): string {
      return root.applyMode(value)
    }
    function open(): void {
      root.open("{}")
    }
    function close(): void {
      root.close()
    }
    function toggle(): void {
      if (root.opened)
        root.close()
      else
        root.open("{}")
    }
  }

  Component.onCompleted: {
    if (root.sourceDir)
      hook.running = true
    readMode.running = true
    load.running = true
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: overlay
      required property var modelData
      readonly property string screenName: modelData ? String(modelData.name) : ""

      screen: modelData
      visible: root.opened && (root.focusedName === "" || screenName === root.focusedName)
      anchors {
        top: true
        right: true
        bottom: true
        left: true
      }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "vhladko-hints"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}

      BorderSurface {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))
        radius: 0

        readonly property int pad: Style.space(12)
        readonly property int colMin: Style.space(360)
        readonly property int cols: Math.max(1, Math.floor((overlay.width - pad * 2) / colMin))

        height: Math.min(body.implicitHeight + borderTop + pad * 2 + borderBottom, overlay.height * 0.8)

        onColsChanged: {
          if (root.colCount !== cols) {
            root.colCount = cols
            root.rebuild()
          }
        }

        ColumnLayout {
          id: body
          anchors.fill: parent
          anchors.topMargin: card.borderTop + card.pad
          anchors.rightMargin: card.borderRight + card.pad
          anchors.bottomMargin: card.borderBottom + card.pad
          anchors.leftMargin: card.borderLeft + card.pad
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            text: root.viewModel.title
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.5
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.space(32)

            Repeater {
              model: root.viewModel.columns

              delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Style.space(6)

                Repeater {
                  model: modelData

                  delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.topMargin: (index > 0 && modelData.header === true) ? Style.space(10) : 0
                    spacing: Style.space(2)

                    Text {
                      visible: modelData.header === true
                      textFormat: Text.PlainText
                      text: modelData.label
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 1.2
                    }

                    RowLayout {
                      visible: modelData.header !== true
                      Layout.fillWidth: true
                      spacing: Style.space(8)

                      Text {
                        textFormat: Text.PlainText
                        Layout.preferredWidth: Style.space(110)
                        text: modelData.label
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Text {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        text: modelData.description
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            text: "Super + K to search"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
