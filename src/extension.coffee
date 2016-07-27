# Extension - represents a Yang Extension

Yang = require './yang'

class Extension extends Yang
  @scope = 
    argument:    '0..1'
    description: '0..1'
    reference:   '0..1'
    status:      '0..1'
  
  constructor: (name, spec={}) ->
    unless spec instanceof Object
      throw @error "must supply 'spec' as object"

    spec.scope ?= {}
    super 'extension', name, spec
      
    Object.defineProperties this,
      argument:  value: spec.argument
      resolve:   value: spec.resolve   ? ->
      construct: value: spec.construct ? (x) -> x
      predicate: value: spec.predicate ? -> true
      compose:   value: spec.compose, writable: true

    eval: (data) ->

module.exports = Extension
