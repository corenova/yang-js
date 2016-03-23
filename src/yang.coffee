#
# Yang - bold outward facing expression and interactive manifestation
#

# TODO - consider removing this dependency
synth = require 'data-synth'
yaml  = require 'js-yaml'

class Yang extends synth.Meta
  constructor: (@map) ->
    @attach k, v for k, v of @map when k not in [ 'module', 'specification' ]

  dump: ->
    out = synth.extract.call @map, 'specification'
    out[k] = v for k, v of @map when v not instanceof Function
    yaml.dump out, lineWidth: -1

module.exports = Yang
