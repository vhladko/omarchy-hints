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
  property bool delayReady: false
  property var rows: []
  property var viewModel: ({ title: "", rows: [], columns: [] })

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
    root.viewModel = Hints.view(root.rows, root.mask)
  }

  function accept(seq, nextMask) {
    var n = Number(seq)
    if (isFinite(n) && n > 0 && n < root.lastSeq)
      return
    if (isFinite(n) && n > 0)
      root.lastSeq = n

    root.mask = Number(nextMask) || 0
    if ((root.mask & 64) === 0) {
      root.delayReady = false
      root.opened = false
      wait.stop()
      return
    }

    if (root.rows.length === 0 && !load.running)
      load.running = true

    if (root.opened) {
      root.rebuild()
      return
    }

    wait.restart()
  }

  function maybeOpen() {
    if ((root.mask & 64) === 0)
      return
    if (!root.delayReady)
      return
    if (root.rows.length === 0)
      return
    root.rebuild()
    root.opened = root.viewModel.rows.length > 0
  }

  function open(payloadJson) {
    root.accept(root.lastSeq + 1, 64)
    root.delayReady = true
    root.maybeOpen()
  }

  function close() {
    root.mask = 0
    root.delayReady = false
    root.opened = false
    wait.stop()
  }

  Timer {
    id: wait
    interval: 200
    onTriggered: {
      root.delayReady = true
      root.maybeOpen()
    }
  }

  Process {
    id: load
    command: ["omarchy-menu-keybindings", "--print"]
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

  IpcHandler {
    target: "vhladko.hints"
    function state(sequence: int, mask: int): void {
      root.accept(sequence, mask)
    }
    function ping(): string {
      return "ok"
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
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Style.gapsOut
        anchors.bottomMargin: Style.gapsOut
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))
        radius: Style.cornerRadius

        readonly property int pad: Style.space(10)

        implicitWidth: body.implicitWidth + borderLeft + pad * 2 + borderRight
        implicitHeight: body.implicitHeight + borderTop + pad * 2 + borderBottom
        width: Math.min(implicitWidth, overlay.width - Style.gapsOut * 2)
        height: Math.min(implicitHeight, overlay.height - Style.gapsOut * 2)

        ColumnLayout {
          id: body
          anchors.fill: parent
          anchors.topMargin: card.borderTop + card.pad
          anchors.rightMargin: card.borderRight + card.pad
          anchors.bottomMargin: card.borderBottom + card.pad
          anchors.leftMargin: card.borderLeft + card.pad
          spacing: Style.space(6)

          Text {
            textFormat: Text.PlainText
            text: root.viewModel.title
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.5
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(1, Style.space(1))
            color: Color.popups.border
          }

          RowLayout {
            spacing: Style.space(16)

            Repeater {
              model: root.viewModel.columns

              delegate: ColumnLayout {
                required property var modelData
                spacing: Style.space(4)

                Repeater {
                  model: modelData

                  delegate: RowLayout {
                    required property var modelData
                    spacing: Style.space(8)

                    Text {
                      textFormat: Text.PlainText
                      text: modelData.label
                      color: Color.accent
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
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
      }
    }
  }
}
