#
# Yang - bold outward facing expression and interactive manifestation
#

# TODO - consider removing this dependency
synth = require 'data-synth'
yaml  = require 'js-yaml'

class Yang extends synth.Meta
  constructor: (@origin) ->
    @attach k, v for k, v of @origin.map when v instanceof Function

  dump: ->
    out = synth.extract.call @origin.map, 'specification'
    out[k] = v for k, v of @origin.map when v not instanceof Function
    yaml.dump out, lineWidth: -1

module.exports = Yang
