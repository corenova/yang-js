# expression - cascading symbolic definitions

events  = require 'events'
Element = require './element'

class Expression
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (kind, tag, opts={}) ->
    unless kind? and opts instanceof Object
      throw @error "must supply 'kind' and 'opts' to create a new Expression"
    tag = undefined unless !!tag
    Object.defineProperties this,
      kind:        value: kind, enumerable: true
      tag:         value: tag,  enumerable: true, writable: true
      parent:      value: opts.parent, writable: true
      scope:       value: opts.scope
      binding:     value: opts.binding, writable: true
      represent:   value: opts.represent, writable: true
      expressions: value: []
      resolve:     value: opts.resolve   ? ->
      construct:   value: opts.construct ? (x) -> x
      predicate:   value: opts.predicate ? -> true
      compose:     value: opts.compose   ? ->
      _events: writable: true

    @resolve   = @resolve.bind this
    @construct = @construct.bind this
    @predicate = @predicate.bind this
    @compose   = @compose.bind this

    @[k] = v for own k, v of opts when k not of this

  bind: (data) ->
    return unless data instanceof Object
    if data instanceof Function
      @binding = data
      return this
    (@locate key)?.bind binding for key, binding of data
    return this

  locate: (key, rest...) ->
    return unless typeof key is 'string' and !!key
    if rest.length is 0
      [ key, rest... ] = key.split('/').filter (e) -> !!e
    [ kind..., tag ] = key.split ':'
    for k, v of this when v instanceof Array
      continue if kind.length and k isnt kind[0]
      for expr in v when expr.tag is tag
        return expr if rest.length is 0
        return expr.locate rest...
    return undefined
      
  eval: (data, opts={}) ->
    opts.adaptive ?= true
    data = @construct data
    unless @predicate data
      throw @error "predicate validation error during eval", data
    if opts.adaptive
      @once 'extended', arguments.callee.bind(this, data)
    return data

  propertize: (key, value, opts={}) ->
    unless opts instanceof Object
      throw @error "unable to propertize with invalid opts"
      
    opts.expr ?= this
    return new Element key, value, opts
    
  update: (obj, key, value, opts={}) ->
    return unless obj instanceof Object and key?

    property = @propertize key, value, opts
    property.parent = obj
          
    # update containing object with this property for reference
    unless obj.hasOwnProperty '__'
      Object.defineProperty obj, '__', writable: true, value: {}
    obj.__[key] = property

    console.debug? "attach property '#{key}' and return updated obj"
    console.debug? property
    Object.defineProperty obj, key, property

  # primary mechanism for defining sub-expressions
  extends: (exprs...) ->
    exprs = ([].concat exprs...).filter (x) -> x? and !!x
    return this unless exprs.length > 0
    exprs.forEach (expr) => @_extend expr
    @emit 'extended', exprs
    return this

  # private helper, should not be called directly
  _extend: (expr) ->
    unless expr instanceof Expression
      throw @error "cannot extend a non-Expression into an Expression", expr

    expr.parent ?= this
    key = expr.kind
    if not @scope?
      @[key] = expr
      return

    unless key of @scope
      throw @error "scope violation - invalid '#{key}' extension found"

    switch @scope[key]
      when '0..n', '1..n'
        unless @hasOwnProperty key
          Object.defineProperty this, key,
            enumerable: true
            value: [ expr ]
        else @[key].push expr
      when '0..1', '1'
        unless @hasOwnProperty key
          Object.defineProperty this, key,
            enumerable: true
            value: expr
        else
          throw @error "constraint violation for '#{key}' - cannot define more than once"
      else
        throw @error "unrecognized scope constraint defined for '#{key}' with #{@scope[key]}"
          
    @expressions.push expr

  # Looks for matching Expressions using kind and tag (up the hierarchy)
  #
  # If called with recursive false, it will only look at
  # immediate children.
  lookup: (kind, tag, recursive=true) ->
    #console.log "looking for #{kind} #{tag} in #{@kind}"
    res = switch
      when this not instanceof Object then undefined
      when not kind? then undefined
      when not tag?  then @[kind]
      when (@hasOwnProperty kind) and @[kind] instanceof Array
        match = undefined
        for expr in @[kind] when expr? and expr.tag is tag
          match = expr; break
        match

    res ?= @parent.lookup arguments... if recursive is true and @parent?
    return res
      
  contains: (kind, tag) -> try (@lookup kind, tag, false)?

  error: (msg, context=this) ->
    node = this
    prefix = while (node = node.parent) and node.kind isnt 'registry'
      node.tag ? node.kind
    prefix = prefix.reverse().join '/'
    prefix = '//' + prefix if !!prefix
    unless @tag?
      prefix += '[constructor]'
    else
      prefix += "[#{@kind}/#{@tag}]"
    res = new Error "#{prefix} #{msg}"
    res.name = "ExpressionError"
    res.context = context
    return res

  # converts to a simple JS object
  # 
  tokenize = (keys...) ->
    [].concat (keys.map (x) -> ((x?.split? '.')?.filter (e) -> !!e) ? [])...

  objectify = (keys..., val) ->
    composite = tokenize keys...
    unless composite.length
      return val ? {}

    obj = root = {}
    while (k = composite.shift())
      last = r: root, k: k
      root = root[k] = {}
    last.r[last.k] = val
    obj

  # converts to a simple JS object
  toObject: ->
    console.debug? "converting #{@kind} with #{@expressions.length}"
    if Object.keys(@scope).length
      sub = @expressions.reduce ((a,b) ->
        for k, v of b.toObject()
          if a[k] instanceof Object
            a[k][kk] = vv for kk, vv of v if v instanceof Object
          else
            a[k] = v
        return a
      ), {}
      unless @tag?
        "#{@kind}": sub
      else
        "#{@kind}": "#{@tag}": sub
    else
      "#{@kind}": @tag

module.exports = Expression
