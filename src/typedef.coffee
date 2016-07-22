# Typedef - represents a Yang Typedef

Expression = require './expression'

class Typedef extends Expression
  constructor: (name, spec={}) ->
    unless spec instanceof Object
      throw @error "must supply 'spec' as object"

    super 'typedef', name

    # opts.scope ?= {}
    # Object.defineProperties this,
    #   scope:     value: opts.scope
    #   argument:  value: opts.argument, writable: true

    #   construct: value: opts.construct
    #   resolve:   value: opts.resolve   ? ->
    #   evaluate:  value: opts.evaluate ? (x) -> x
    #   predicate: value: opts.predicate ? -> true
    #   represent: value: opts.represent, writable: true
    #   compose:   value: opts.compose, writable: true
    #   convert:   value: opts.convert, writable: true # should re-consider...

  eval: (data) ->
    unless data instanceof Expression
      throw @error "cannot eval unless data instanceof Expression"
    unless data.kind is @tag
      throw @error "cannot eval '#{data.kind}' using this Extension"

    if data.tag? and not @argument?
      throw @error "cannot contain argument for #{@tag}"
    if @argument? and not data.tag?
      throw @error "must contain argument '#{@argument}' for #{@tag}"

module.exports = Typedef
