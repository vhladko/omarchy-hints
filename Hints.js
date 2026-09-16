.pragma library

var MOD = { SUPER: 64, SHIFT: 1, CTRL: 4, CONTROL: 4, ALT: 8 }

var KEYS = {
  RETURN: "Enter",
  ENTER: "Enter",
  ESCAPE: "Esc",
  SPACE: "Space",
  TAB: "Tab",
  BACKSPACE: "Backspace",
  DELETE: "Delete",
  PRINT: "Print",
  LEFT: "←",
  RIGHT: "→",
  UP: "↑",
  DOWN: "↓",
  HOME: "Home",
  END: "End",
  PAGEUP: "PgUp",
  PAGEDOWN: "PgDn",
  COMMA: ",",
  PERIOD: ".",
  MINUS: "-",
  EQUAL: "=",
  SLASH: "/",
  GRAVE: "~"
}

function title(mask) {
  var n = Number(mask)
  if (!isFinite(n) || n <= 0) return ""
  var parts = []
  if (n & 64) parts.push("SUPER")
  if (n & 1) parts.push("SHIFT")
  if (n & 4) parts.push("CTRL")
  if (n & 8) parts.push("ALT")
  return parts.join(" + ")
}

function keyName(raw) {
  var value = String(raw || "").trim()
  if (!value) return ""
  var upper = value.toUpperCase()
  if (KEYS[upper]) return KEYS[upper]
  if (/^F\d+$/i.test(value)) return upper
  if (value.length === 1) return upper
  return value
}

function chordMask(parts) {
  var mask = 0
  var key = ""
  for (var i = 0; i < parts.length; i++) {
    var token = String(parts[i] || "").trim().toUpperCase()
    if (!token) continue
    if (MOD[token] !== undefined) mask |= MOD[token]
    else key = parts[i]
  }
  return { mask: mask, key: key }
}

var ORDER = ["Menu", "Apps", "Windows", "Workspaces", "Panels", "Capture", "Clipboard", "System", "Other"]

function groupOf(row) {
  var d = String(row.description || "").toLowerCase()
  var cmd = (String(row.dispatcher || "") + " " + String(row.arg || "")).toLowerCase()
  var blob = d + " " + cmd

  if (/omarchy-capture|hyprpicker|screenshot|screenrecord|color picker|ocr|webcam/.test(blob))
    return "Capture"
  if (/clipboard|universal copy|universal paste|universal cut|sendshortcut/.test(blob))
    return "Clipboard"
  if (/omarchy-menu/.test(cmd) || /\bmenu\b|keybindings/.test(d))
    return "Menu"
  if (/omarchy-shell|omarchy-notification|omarchy-reminder|omarchy-audio/.test(cmd) ||
      /bar panel|^audio$|^bluetooth$|^network$|^wifi|^display$|^power$|^calendar$|^emojis?$|^calculator$|^activity|weather|battery|reminder|^show time$/.test(d))
    return "Panels"
  if (/workspace|scratchpad/.test(d) || /hl\.dsp\.workspace|workspace/.test(cmd))
    return "Workspaces"
  if (/omarchy-hyprland-window|hl\.dsp\.window|hl\.dsp\.group|hl\.dsp\.layout/.test(cmd) ||
      /focus\(\s*\{\s*direction|focus\(\s*\{\s*monitor/.test(cmd) ||
      /floating|full screen|full width|close window|split|pop window|swap window|resize window|expand window|shrink window|group|tiling|pseudo|window /.test(d))
    return "Windows"
  if (/omarchy-launch|launch-|webapp|uwsm-app/.test(cmd) || /terminal|browser|file manager|editor/.test(d))
    return "Apps"
  if (/lock|nightlight|idle|notification|zoom|theme|scale|lid|clamshell|dictation|brightness|backlight|eject|agent|transcode/.test(d) ||
      /omarchy-system|omarchy-toggle|omarchy-hyprland-monitor|omarchy-brightness|omarchy-agent|omarchy-transcode|voxtype|eject/.test(cmd))
    return "System"
  return "Other"
}

function parseLine(line) {
  var fields = String(line || "").split("\t")
  var text = fields[0] || ""
  var dispatcher = fields[1] || ""
  var arg = fields.slice(2).join("\t")
  var cut = text.indexOf("→")
  if (cut < 0) cut = text.indexOf("->")
  if (cut < 0) return null
  var left = text.slice(0, cut).trim()
  var description = text.slice(cut + 1).trim()
  if (!left || !description) return null

  var chords = left.split(" / ")
  var mask = -1
  var labels = []
  for (var i = 0; i < chords.length; i++) {
    var parts = chords[i].replace(/\+/g, " ").split(/\s+/)
    var parsed = chordMask(parts)
    if (!parsed.key) continue
    if (mask < 0) mask = parsed.mask
    if (parsed.mask === mask) labels.push(keyName(parsed.key))
  }
  if (mask < 0 || labels.length === 0) return null
  var row = {
    mask: mask,
    label: labels.join(" / "),
    description: description,
    dispatcher: dispatcher,
    arg: arg
  }
  row.group = groupOf(row)
  return row
}

function parse(text) {
  var lines = String(text || "").split("\n")
  var rows = []
  for (var i = 0; i < lines.length; i++) {
    var row = parseLine(lines[i])
    if (row) rows.push(row)
  }
  return rows
}

function filter(rows, mask) {
  var n = Number(mask)
  if (!isFinite(n)) n = 0
  var out = []
  var source = Array.isArray(rows) ? rows : []
  for (var i = 0; i < source.length; i++) {
    if (source[i].mask === n) out.push(source[i])
  }
  return out
}

function workspaceKind(description) {
  var d = String(description || "").toLowerCase()
  if (/^switch to workspace \d+$/.test(d)) return "switch"
  if (/^move window to workspace \d+$/.test(d)) return "move"
  if (/^move window silently to workspace \d+$/.test(d)) return "silent"
  return ""
}

function collapse(shown) {
  var buckets = { switch: [], move: [], silent: [] }
  var rest = []
  for (var i = 0; i < shown.length; i++) {
    var kind = workspaceKind(shown[i].description)
    if (kind) buckets[kind].push(shown[i])
    else rest.push(shown[i])
  }

  function fold(kind, description) {
    var list = buckets[kind]
    if (list.length === 1) {
      rest.push(list[0])
      return
    }
    if (list.length === 0) return
    rest.push({
      mask: list[0].mask,
      label: "1–0",
      description: description,
      group: "Workspaces",
      collapsed: true
    })
  }

  fold("switch", "Switch workspace")
  fold("move", "Move to workspace")
  fold("silent", "Move to workspace (stay)")
  return rest
}

var BEGINNER = {
  "keybindings": true,
  "omarchy menu": true,
  "terminal": true,
  "browser": true,
  "file manager": true,
  "close window": true,
  "full screen": true,
  "toggle window floating/tiling": true,
  "switch workspace": true,
  "move to workspace": true
}

function beginner(shown) {
  var out = []
  for (var i = 0; i < shown.length; i++) {
    var d = String(shown[i].description || "").toLowerCase()
    if (BEGINNER[d]) out.push(shown[i])
  }
  return out
}

function groups(shown) {
  var buckets = {}
  for (var i = 0; i < shown.length; i++) {
    var name = shown[i].group || "Other"
    if (!buckets[name]) buckets[name] = []
    buckets[name].push(shown[i])
  }
  var out = []
  for (var g = 0; g < ORDER.length; g++) {
    var list = buckets[ORDER[g]]
    if (!list || list.length === 0) continue
    var items = [{ header: true, label: ORDER[g], description: "" }]
    for (var j = 0; j < list.length; j++) {
      items.push({
        header: false,
        label: list[j].label,
        description: list[j].description
      })
    }
    out.push(items)
  }
  return out
}

function pack(grouped, cols) {
  var n = Math.max(1, Math.floor(Number(cols) || 1))
  var columns = []
  var heights = []
  for (var i = 0; i < n; i++) {
    columns.push([])
    heights.push(0)
  }
  for (var g = 0; g < grouped.length; g++) {
    var items = grouped[g]
    var best = 0
    for (var c = 1; c < n; c++) {
      if (heights[c] < heights[best])
        best = c
    }
    for (var j = 0; j < items.length; j++)
      columns[best].push(items[j])
    heights[best] += items.length
  }
  var filled = []
  for (var k = 0; k < n; k++) {
    if (columns[k].length)
      filled.push(columns[k])
  }
  return filled
}

function view(rows, mask, cols, mode) {
  if (mode === "off")
    return { title: title(mask), rows: [], columns: [] }
  var shown = collapse(filter(rows, mask))
  if (mode === "beginner")
    shown = beginner(shown)
  return {
    title: title(mask),
    rows: shown,
    columns: pack(groups(shown), cols)
  }
}
