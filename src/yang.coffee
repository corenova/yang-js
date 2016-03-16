#
# Yang - bold outward facing expression and interactive manifestation
#

# TODO - consider removing this dependency
synth = require 'data-synth'

class Yang extends synth.Meta
  constructor: (map, @parent) -> @attach k, v for k, v of map
  load: -> @parent?.load? arguments...

module.exports = Yang
