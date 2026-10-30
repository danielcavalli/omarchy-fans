.pragma library

var PROFILES = [
  { value: "quiet", label: "Quiet" },
  { value: "balanced", label: "Balanced" },
  { value: "cool", label: "Cool" },
  { value: "max", label: "Max" },
  { value: "bios", label: "BIOS" }
]

function temp(value) {
  return value === null || value === undefined ? "--" : Math.round(value) + "°"
}

function tempC(value) {
  return value === null || value === undefined ? "--" : Math.round(value) + "°C"
}

function profileLabel(name) {
  for (var i = 0; i < PROFILES.length; i++) if (PROFILES[i].value === name) return PROFILES[i].label
  return name || ""
}

// The hotter of the two sources, measured against its own limit.
function hottest(status) {
  if (!status || !status.temps) return null
  var best = null
  var sources = ["cpu", "gpu"]
  for (var i = 0; i < sources.length; i++) {
    var s = sources[i]
    var t = status.temps[s]
    if (t === null || t === undefined) continue
    var limit = status.limits ? status.limits[s] : 90
    if (best === null || t - limit > best.value - best.limit) best = { source: s, value: t, limit: limit }
  }
  return best
}

function alert(status) {
  if (!status) return false
  if (status.safety && status.safety.length > 0) return true
  var h = hottest(status)
  return h !== null && h.value >= h.limit - 5
}

function reasonText(reason) {
  if (reason === "cpu") return "following the CPU"
  if (reason === "gpu") return "following the GPU"
  if (reason === "bios") return "on the BIOS curve"
  return reason || ""
}

function rpmText(list) {
  var out = []
  for (var i = 0; i < (list || []).length; i++) {
    if (list[i] !== null && list[i] !== undefined) out.push(Number(list[i]).toLocaleString(Qt.locale("en_US"), "f", 0) + " rpm")
  }
  return out.length > 0 ? out.join(", ") : "no tach"
}

function boostLeft(status) {
  if (!status || !status.boost) return 0
  return Math.max(0, Math.round(status.boost.until - Date.now() / 1000))
}

function gpuDetail(status) {
  if (!status || !status.gpus || status.gpus.length === 0) return ""
  var parts = []
  for (var i = 0; i < status.gpus.length; i++) {
    var g = status.gpus[i]
    var bits = []
    if (g.watts !== undefined) bits.push(g.watts + " W")
    if (g.fan !== undefined) bits.push("card fans " + g.fan + "%")
    if (bits.length > 0) parts.push(bits.join(", "))
  }
  return parts.join("; ")
}

function groupKeys(status) {
  return status && status.groups ? Object.keys(status.groups) : []
}
