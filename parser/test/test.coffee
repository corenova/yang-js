Y = require '../lib/yang-parser'

yam = '''
container/* weird comment */bar {
  description
    "     This container was written \nfor the purpose \t
     of testing YANG parser written using the
       \\"Comparse\\" parsing library. "
  + 'Your "Comparse" team.';
  leaf foo { // line comment
    type uint8;
    default 42;
  }
}
'''

try
  console.log Y.parse yam, "container"
catch e
  if e.name is "ParsingError"
    console.log "Offset", e.offset, \
      "(line", e.coords[0] + ",", "column", e.coords[1] + "):", e.message
  else
    throw e
