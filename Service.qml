import QtQuick
import Quickshell
import Quickshell.Io

// The connection to omarchy-fansd: one Unix socket, JSON lines. It subscribes once and the
// service pushes its status every tick; commands go over the same socket and their replies
// carry the new status. A failed or dropped socket is thrown away and made again, backing off
// to 30 s while the service is away.
Item {
  id: root

  property var settings: ({})
  readonly property string socketPath: settings && settings.socketPath ? String(settings.socketPath) : "/run/omarchy-fans/socket"
  property var status: null
  property bool online: false
  property bool linked: false
  property string lastError: ""
  property real updatedAt: 0

  function send(payload) {
    if (!linked || !link.item) {
      lastError = "omarchy-fansd is not running"
      return false
    }
    link.item.write(JSON.stringify(payload) + "\n")
    link.item.flush()
    return true
  }

  function setProfile(name) { return send({ cmd: "profile", name: String(name) }) }
  function boost(duty, seconds) { return send({ cmd: "boost", duty: Number(duty), seconds: String(seconds) }) }
  function boostOff() { return send({ cmd: "boost", off: true }) }
  function setCurve(group, source, points) { return send({ cmd: "curve", group: group, source: source, points: points }) }
  function resetCurves(group) { return send(group ? { cmd: "curve-reset", group: group } : { cmd: "curve-reset" }) }

  function handle(line) {
    var reply
    try { reply = JSON.parse(line) } catch (e) { return }
    if (reply.ok && reply.status) {
      status = reply.status
      online = true
      lastError = ""
      updatedAt = Date.now()
    } else if (!reply.ok) {
      lastError = String(reply.error || "refused")
    }
  }

  function dropped() {
    linked = false
    online = false
  }

  function reconnect() {
    dropped()
    link.active = false
    Qt.callLater(function() { link.active = true })
  }

  onSocketPathChanged: reconnect()

  Loader {
    id: link
    active: true
    sourceComponent: Component {
      Socket {
        path: root.socketPath
        connected: true
        parser: SplitParser { onRead: function(line) { root.handle(line) } }
        onConnectionStateChanged: {
          if (connected) {
            root.linked = true
            retry.interval = 3000
            write(JSON.stringify({ cmd: "subscribe" }) + "\n")
            flush()
          } else {
            root.dropped()
          }
        }
        onError: function(error) { root.dropped() }
      }
    }
  }

  Timer {
    id: retry
    interval: 3000
    repeat: true
    running: true
    onTriggered: {
      if (!root.linked) {
        interval = Math.min(30000, interval * 2)
        root.reconnect()
      } else if (root.updatedAt > 0 && Date.now() - root.updatedAt > 10000) {
        root.reconnect()
      }
    }
  }
}
