# Extension - represents a Yang Extension

Expression = require './expression'

class Extension extends Expression
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

module.exports = Extension
