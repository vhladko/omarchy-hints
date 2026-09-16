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

function parseLine(line) {
  var text = String(line || "")
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
  return { mask: mask, label: labels.join(" / "), description: description }
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

function chunk(rows, size) {
  var columns = []
  var n = size > 0 ? size : 18
  for (var i = 0; i < rows.length; i += n)
    columns.push(rows.slice(i, i + n))
  return columns
}

function view(rows, mask) {
  var shown = filter(rows, mask)
  var per = 18
  if (shown.length > 54) per = Math.ceil(shown.length / 3)
  return {
    title: title(mask),
    rows: shown,
    columns: chunk(shown, per)
  }
}
