#
# Yang - bold outward facing expression and interactive manifestation
#

# TODO - consider removing this dependency
synth = require 'data-synth'

class Yang extends synth.Meta
  constructor: (@origin) ->
    @attach k, v for k, v of @origin.map when v instanceof Function

  dump: -> @origin.dump this, arguments...

module.exports = Yang
