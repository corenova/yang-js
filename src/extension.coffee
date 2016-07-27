# Extension - represents a Yang Extension

Element = require './element'

class Extension extends Element
  
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

module.exports = Extension
