# Extension - represents a Yang Extension

Yang    = require './yang'
Element = require './element'

class Extension extends Yang
  constructor: (name, @spec={}) ->
    unless @spec instanceof Object
      throw @error "must supply 'spec' as object"

    @spec.scope     ?= {}
    @spec.construct ?= ->
    @spec.resolve   ?= ->
    @spec.evaluate  ?= (x) -> x
    @spec.predicate ?= -> true

    #compose:   value: spec.compose, writable: true
    #represent: value: spec.represent, writable: true
    
    Element.constructor.call this, 'extension', name,
      scope: 
        argument:    '0..1'
        description: '0..1'
        reference:   '0..1'
        status:      '0..1'

    @extends 'argument extension-name;'

  eval: (data, opts={}) ->
    return data unless data instanceof Element

    unless opts.schema? and opts.parent?
      throw @error "cannot eval without 'opts.schema' and 'opts.parent'"

    kind = switch
      when opts.schema.prf? then "#{opts.schema.prf}:#{opts.schema.kw}"
      else opts.schema.kw
    tag = opts.schema.arg if !!opts.schema.arg

    # special handling when "extension" keyword being defined
    if kind is 'extension'
      unless tag?
        throw @error "must contain 'extension-name'"
      source = opts.parent.root.lookup 'extension', tag
      if source?
        source.extends schema.substmts....
        return source 
      console.warn @error "extension #{tag} is missing implementation"

    if tag? and not @spec.argument?
      throw @error "cannot contain argument for #{@tag}"
    if @spec.argument? and not tag?
      throw @error "must contain argument '#{@spec.argument}' for #{@tag}"

    Element.constructor.call data, kind, tag,
      parent: opts.parent
      scope:  @spec.scope

    data.extends schema.substmts...

    # perform final scoped constraint validation
    for kind, constraint of data.scope when constraint in [ '1', '1..n' ]
      unless data.hasOwnProperty kind
        throw @error "constraint violation for required '#{kind}' = #{constraint}"

    Object.defineProperty data, 'source', value: this

    @debug? "construct #{data.kind}:#{data.tag}..."
    @spec.construct.call data

  merge: (elem) ->
    unless elem instanceof Element
      throw @error "cannot merge a non-Element into an Element", elem
    return super unless elem.kind is 'argument'
    
    @[elem.kind] = elem
    elem.parent = this
    return elem

module.exports = Extension
