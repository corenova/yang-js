#
# Yang - bold outward facing expression and interactive manifestation
#

# TODO - consider removing this dependency
synth = require 'data-synth'

class Yang extends synth.Meta
  constructor: (@origin) -> @attach k, v for k, v of @origin.map
  load: -> @origin.load arguments...
  toString: -> @origin.toString()

module.exports = Yang
