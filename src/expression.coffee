# expression - evaluable Element

Element = require './element'
Emitter = (require 'events').EventEmitter

class Instance extends Emitter
  constructor: (data, schema) ->
    return unless data? and data.__ instanceof Object
    Object.defineProperties this,
      '__': value: { schema: schema }
      '_events': writable: true
    Object.defineProperties this, data.__
    for own k, v of data.__
      v.parent = this
      v.on 'change', (x) => @emit 'change', x

class Expression extends Element
  constructor: (kind, tag, source={}) ->
    unless source instanceof Object
      throw @error "cannot create new Expression without 'source' object"

    { argument, binding, scope, resolved, convert } = source
    source = source.source if source.hasOwnProperty 'source'
    source.resolve   ?= ->
    source.construct ?= (x) -> x
    source.predicate ?= -> true
    super
    @scope = scope
    resolved ?= false
    Object.defineProperties this,
      source:   value: source,   writable: true
      argument: value: argument, writable: true
      binding:  value: binding,  writable: true
      resolved: value: resolved, writable: true
      convert:  value: convert,  writable: true
      exprs: get: (-> @elements.filter (x) -> x instanceof Expression ).bind this
    
  resolve: ->
    @debug? "resolve: enter..."
    @emit 'resolve:before', arguments
    @source.resolve.apply this, arguments if @resolved is false
    if @tag? and not @argument?
      throw @error "cannot contain argument '#{@tag}' for expression '#{@kind}'"
    if @argument? and not @tag?
      throw @error "must contain argument '#{@argument}' for expression '#{@kind}'"
    @elements.forEach (x) -> x.resolve arguments...
    @resolved = true
    @emit 'resolve:after'
    @debug? "resolve: ok"
    return this
    
  bind: (data) ->
    return unless data instanceof Object
    if data instanceof Function
      @debug? "bind: registering function"
      @binding = data
      return this
    for key, binding of data      
      try @locate(key).bind binding
      catch e
        throw e if e.name is 'ExpressionError'
        throw @error "failed to bind to '#{key}' (schema-path not found)", e
    return this

  eval: (data, opts={}) ->
    opts.adaptive ?= true
    @resolve()
    @emit 'eval:before', data
    data = @source.construct.call this, data
    unless @source.predicate.call this, data
      throw @error "predicate validation error during eval", data
    if opts.adaptive
      @once 'changed', arguments.callee.bind(this, data, opts)
    @emit 'eval:after', data
    return data

  create: (data, opts={}) ->
    data = @eval arguments...
    return unless data?
    new Instance data, this

  error: ->
    res = super
    res.name = 'ExpressionError'
    return res

module.exports = Expression
