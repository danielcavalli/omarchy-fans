import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar widget and panel for omarchy-fansd. The bar shows the hotter of the CPU and GPU (red near
// a limit); left click opens the panel, right click cycles the profile, middle click boosts.
Panel {
  id: root
  moduleName: "rio.dan.fans"
  ipcTarget: "rio.dan.fans"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var status: fans.status
  readonly property bool online: fans.online && status !== null
  readonly property var hottest: Model.hottest(status)
  readonly property bool alert: online && Model.alert(status)
  readonly property bool onBios: online && status.profile === "bios"
  readonly property string label: "󰈐 " + (online && hottest ? Model.temp(hottest.value) : "--")
  property int boostLeft: 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function cycleProfile() {
    if (!online) return
    var order = ["quiet", "balanced", "cool", "max"]
    var i = order.indexOf(status.profile)
    fans.setProfile(order[(i + 1) % order.length])
  }

  function toggleBoost() {
    if (!online) return
    if (status.boost) fans.boostOff()
    else fans.boost(100, "15m")
  }

  onOpenedChanged: if (opened) {
    if (panelFlick) panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: fans
    settings: root.settings
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.online && root.status.boost !== null && root.status.boost !== undefined
    triggeredOnStart: true
    onTriggered: root.boostLeft = Model.boostLeft(root.status)
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function status(): string { return JSON.stringify(fans.status) }
    function profile(name: string): string { return fans.setProfile(name) ? "ok" : fans.lastError }
    function boost(duty: string, duration: string): string { return fans.boost(duty, duration) ? "ok" : fans.lastError }
    function boostOff(): string { return fans.boostOff() ? "ok" : fans.lastError }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    active: root.alert
    dimmed: !root.online || root.onBios
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleProfile()
      else if (b === Qt.MiddleButton) root.toggleBoost()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var i = "12345".indexOf(t)
        if (i >= 0 && root.online) fans.setProfile(Model.PROFILES[i].value)
        else if (t === "b" || t === "B") root.toggleBoost()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "Fans"
            meta: !root.online ? "Service offline"
              : Model.profileLabel(root.status.profile) + " · CPU " + Model.tempC(root.status.temps.cpu)
                + " · GPU " + Model.tempC(root.status.temps.gpu)
            detail: !root.online ? ""
              : (root.status.safety && root.status.safety.length > 0)
                ? "Safety: " + root.status.safety.join(", ") + " at its limit, every fan at 100%"
                : Model.gpuDetail(root.status)
            foreground: root.alert ? root.urgent : root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰈐"
                color: root.alert ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            visible: !root.online
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "omarchy-fansd is not reachable at " + fans.socketPath
              + ". Install it with the plugin's setup script:\n~/.config/omarchy/plugins/rio.dan.fans/setup"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: fans.lastError !== "" && root.online
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: fans.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          ButtonGroup {
            visible: root.online
            width: parent.width
            options: Model.PROFILES
            value: root.online ? root.status.profile : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            focusable: false
            onChanged: function(value) { fans.setProfile(value) }
          }

          Button {
            visible: root.online
            text: root.online && root.status.boost
              ? "End boost (" + Math.floor(root.boostLeft / 60) + "m " + (root.boostLeft % 60) + "s left)"
              : "Boost to 100% for 15 min"
            iconText: "󰈐"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.toggleBoost()
          }

          PanelSeparator {
            visible: root.online
            foreground: root.foreground
          }

          Repeater {
            model: root.online ? Model.groupKeys(root.status) : []
            delegate: GroupBlock {
              required property string modelData
              width: column.width
              group: root.status.groups[modelData]
            }
          }

          Repeater {
            model: root.online ? root.status.pumps : []
            delegate: Row {
              required property var modelData
              width: column.width
              spacing: Style.space(8)
              Text {
                textFormat: Text.PlainText
                text: "Pump"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                textFormat: Text.PlainText
                text: Model.rpmText([modelData.rpm]) + " · BIOS setting, never touched"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Text {
            visible: root.online
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "1-5 profiles · b boost · right click the bar icon to cycle · `omarchy-fans --help`"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  component GroupBlock: Column {
    id: block
    property var group: ({})
    spacing: Style.space(4)

    RowLayout {
      width: parent.width
      spacing: Style.space(8)
      Text {
        textFormat: Text.PlainText
        text: block.group.label || ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
      Text {
        textFormat: Text.PlainText
        text: Model.rpmText(block.group.rpm)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        textFormat: Text.PlainText
        text: block.group.duty === null || block.group.duty === undefined ? "--" : block.group.duty + "%"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: Model.reasonText(block.group.reason)
        + (block.group.asks ? " · CPU asks " + (block.group.asks.cpu !== undefined ? block.group.asks.cpu + "%" : "--")
          + ", GPU asks " + (block.group.asks.gpu !== undefined ? block.group.asks.gpu + "%" : "--") : "")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    CurveView {
      width: parent.width
      curves: block.group.curves || ({})
      temps: root.status ? root.status.smoothed : ({})
      limits: root.status ? root.status.limits : ({})
      duty: block.group.duty === null || block.group.duty === undefined ? -1 : block.group.duty
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Row {
      spacing: Style.space(12)
      Text {
        textFormat: Text.PlainText
        text: "━ CPU"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        textFormat: Text.PlainText
        text: "━ GPU"
        color: Color.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        textFormat: Text.PlainText
        text: "┄ running duty   ┆ limit"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
