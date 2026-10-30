import QtQuick
import qs.Commons

// A fan group's two curves (duty against temperature), where each source sits now, and the
// duty the group runs at.
Canvas {
  id: root

  property var curves: ({})
  property var temps: ({})
  property var limits: ({})
  property real duty: -1
  property color foreground: Color.foreground
  property color cpuColor: foreground
  property color gpuColor: Color.accent
  property color limitColor: Color.urgent
  property string fontFamily: Style.font.family
  property real minT: 20
  property real maxT: 100

  implicitHeight: Style.space(92)

  onCurvesChanged: requestPaint()
  onTempsChanged: requestPaint()
  onDutyChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onForegroundChanged: requestPaint()

  function colorFor(source) { return source === "gpu" ? gpuColor : cpuColor }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var labelH = Style.space(12)
    var w = width, h = height - labelH
    if (w <= 0 || h <= 0) return
    function x(t) { return (Math.max(minT, Math.min(maxT, t)) - minT) / (maxT - minT) * w }
    function y(d) { return h - Math.max(0, Math.min(100, d)) / 100 * (h - 2) - 1 }

    ctx.lineWidth = 1
    ctx.strokeStyle = Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
    for (var g = 25; g <= 100; g += 25) {
      ctx.beginPath(); ctx.moveTo(0, y(g)); ctx.lineTo(w, y(g)); ctx.stroke()
    }

    ctx.fillStyle = Qt.rgba(foreground.r, foreground.g, foreground.b, 0.5)
    ctx.font = Math.round(Style.font.caption * 0.9) + "px '" + fontFamily + "'"
    for (var t = 20; t <= 100; t += 20) {
      var label = t + "°"
      var lx = Math.min(w - ctx.measureText(label).width, Math.max(0, x(t) - ctx.measureText(label).width / 2))
      ctx.fillText(label, lx, height - 2)
    }

    var sources = Object.keys(curves || {})
    for (var i = 0; i < sources.length; i++) {
      var s = sources[i]
      var pts = curves[s]
      if (!pts || pts.length === 0) continue
      var c = colorFor(s)
      if (limits && limits[s] !== undefined) {
        ctx.strokeStyle = Qt.rgba(limitColor.r, limitColor.g, limitColor.b, 0.35)
        ctx.setLineDash([2, 3])
        ctx.beginPath(); ctx.moveTo(x(limits[s]), 0); ctx.lineTo(x(limits[s]), h); ctx.stroke()
        ctx.setLineDash([])
      }
      ctx.strokeStyle = c
      ctx.lineWidth = Math.max(1.5, Style.space(2))
      ctx.beginPath()
      ctx.moveTo(0, y(pts[0][1]))
      for (var p = 0; p < pts.length; p++) ctx.lineTo(x(pts[p][0]), y(pts[p][1]))
      ctx.lineTo(w, y(pts[pts.length - 1][1]))
      ctx.stroke()

      var now = temps ? temps[s] : null
      if (now !== null && now !== undefined) {
        var duty = pts[0][1]
        if (now >= pts[pts.length - 1][0]) duty = pts[pts.length - 1][1]
        else for (var q = 0; q + 1 < pts.length; q++) {
          if (now >= pts[q][0] && now <= pts[q + 1][0]) {
            duty = pts[q][1] + (pts[q + 1][1] - pts[q][1]) * (now - pts[q][0]) / (pts[q + 1][0] - pts[q][0])
            break
          }
        }
        ctx.fillStyle = c
        ctx.beginPath(); ctx.arc(x(now), y(duty), Math.max(3, Style.space(4)), 0, Math.PI * 2); ctx.fill()
      }
    }

    if (root.duty >= 0) {
      ctx.strokeStyle = Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
      ctx.lineWidth = 1
      ctx.setLineDash([4, 3])
      ctx.beginPath(); ctx.moveTo(0, y(root.duty)); ctx.lineTo(w, y(root.duty)); ctx.stroke()
      ctx.setLineDash([])
    }
  }
}
