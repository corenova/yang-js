#
# Yin - calm internally supportive definitions and generator
#

# external dependencies
yaml    = require 'js-yaml'
coffee  = require 'coffee-script'
Synth   = require 'data-synth'

# local dependencies
Element = require './element'

YIN_SCHEMA = yaml.Schema.create [

  new yaml.Type '!coffee',
    kind: 'scalar'
    resolve:   (data) -> typeof data is 'string'
    construct: (data) -> coffee.eval? data

  new yaml.Type '!coffee/function',
    kind: 'scalar'
    resolve:   (data) -> typeof data is 'string'
    construct: (data) -> coffee.eval? data
    predicate: (obj) -> obj instanceof Function
    represent: (obj) -> obj.toString()
]

# represents YIN specification
class Yin extends Element

  constructor: (schema, parent) ->
    super parent
    try
      schema = yaml.load schema, schema: YIN_SCHEMA if typeof schema is 'string'
    catch e
      throw @error "invalid YIN schema syntax detected", e
    unless schema instanceof Object
      throw @error "must pass in proper YIN schema to parse"

    @set schema
    @set 'synthesizer', Synth

module.exports = Yin
