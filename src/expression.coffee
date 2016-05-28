# expression - cascading symbolic definitions

events   = require 'events'

class Expression
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (keyword, data={}) ->
    unless keyword? and data instanceof Object
      throw @error "must supply 'keyword' and 'data' to create a new Expression"
      
    Object.defineProperties this,
      kw:      writable: true, value: keyword
      parent:  writable: true, value: data.parent
      scope:   writable: true, value: data.scope
      _events: writable: true
    for own k, v of data when k not of this
      Object.defineProperty this, k, enumerable: true, value: v

  # primary mechanism to define sub-expressions
  extend: (expr) ->
    unless expr instanceof Expression
      throw @error "cannot extend a non-Expression into an Expression", expr

    unless @scope?
      unless @hasOwnProperty expr.kw
        Object.defineProperty this, expr.kw,
          enumerable: true
          value: expr
      else
        throw @error "constraint violation for '#{expr.kw}' - cannot define more than once"
      return this

    unless expr.kw of @scope
      throw @error "scope violation - invalid '#{expr.kw}' extension found"

    switch @scope[expr.kw]
      when '0..n', '1..n'
        unless @hasOwnProperty expr.kw
          Object.defineProperty this, expr.kw,
            enumerable: true
            value: [ expr ]
        else @[expr.kw].push expr
      when '0..1', '1'
        unless @hasOwnProperty expr.kw
          Object.defineProperty this, expr.kw,
            enumerable: true
            value: expr
        else
          throw @error "constraint violation for '#{expr.kw}' - cannot define more than once"
    return this

  # recursively look for matching Expression
  resolve: (kw) ->
    return unless kw? and this instanceof Object
    
    if @hasOwnProperty kw
      return @[kw]
      
    return @parent?.resolve? arguments...

  expressions: (filter...) ->
    [].concat (v for own k, v of this when not @scope? or k of @scope)...
    .filter (x) -> x instanceof Expression and (filter.length is 0 or x.kw in filter)

  # TODO: should consider a more generic operation for this function...
  locate: (xpath) ->
    return unless inside? and typeof path is 'string'
    if /^\//.test path
      console.warn "[Element:locate] absolute-schema-nodeid is not yet supported, ignoring #{xpath}"
      return
    [ target, rest... ] = path.split '/'

    console.debug? "[Element:locate] locating #{path}"
    if inside.access instanceof Function
      return switch
        when target is '..'
          if (inside.parent.meta 'synth') is 'list'
            @locate inside.parent.parent, rest.join '/'
          else
            @locate inside.parent, rest.join '/'
        when rest.length > 0 then @locate (inside.access target), rest.join '/'
        else inside.access target

    for key, val of inside when val.hasOwnProperty target
      return switch
        when rest.length > 0 then @locate val[target], rest.join '/'
        else val[target]
    console.warn "[Element:locate] unable to find '#{path}' within #{Object.keys inside}"
    return

  error: (msg, context=@toObject()) ->
    res = new Error msg
    res.name = "ExpressionError"
    res.context = context
    return res

  # converts to a simple JS object
  # 
  copy = (dest={}, sources...) ->
    for src in sources
      for p of src
        switch
          when src[p]?.constructor is Object
            dest[p] ?= {}
            unless dest[p] instanceof Object
              k = dest[p]
              dest[p] = {}
              dest[p][k] = null
            arguments.callee dest[p], src[p]
          else dest[p] = src[p]
    return dest

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

  toObject: ->
    sub = @expressions().reduce ((a,b) -> copy a, b.toObject()), {}
    if Object.keys(sub).length
      objectify @kw, @arg, sub
    else
      objectify @kw, @arg

module.exports = Expression
