fs = require 'fs'
yp = require '../lib/yang-parser'

fname = process.argv[2]
text = fs.readFileSync fname, "utf8"

try
  yp.parse text, "module"
  console.log "Module OK."
catch e
  if e.name is "ParsingError"
    console.log "Parsing failed at", e.offset, "(line", e.coords[0], "column", e.coords[1] + ")"
  else
    throw e
