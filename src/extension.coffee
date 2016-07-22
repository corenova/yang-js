# Extension - represents a Yang Extension

Expression = require './expression'

class Extension extends Expression
  constructor: (name, spec={}) ->
    unless spec instanceof Object
      throw @error "must supply 'spec' as object"

    super 'extension', name
    
    spec.scope ?= {}
    Object.defineProperties this,
      scope:     value: spec.scope
      argument:  value: spec.argument, writable: true

      construct: value: spec.construct ? ->
      resolve:   value: spec.resolve   ? ->
      evaluate:  value: spec.evaluate  ? (x) -> x
      predicate: value: spec.predicate ? -> true
      #compose:   value: spec.compose, writable: true
      #represent: value: spec.represent, writable: true

  eval: (data) ->
    return data unless data instanceof Expression

    # unless data.kind is @tag
    #   throw @error "cannot eval '#{data.kind}' using this Extension '#{@tag}'"
    if data.tag? and not @argument?
      throw @error "cannot contain argument for #{@tag}"
    if @argument? and not data.tag?
      throw @error "must contain argument '#{@argument}' for #{@tag}"

    Object.defineProperties data,
      source: value: this, writable: true
      scope:  value: @scope
    
    @debug? "construct #{data.kind}:#{data.tag}..."
    @construct.call data

module.exports = Extension
