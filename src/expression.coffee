# expression - evaluable Element

Element = require './element'

class Expression extends Element

  constructor: (kind, tag, source={}) ->
    unless source instanceof Object
      throw @error "cannot create new Expression without 'source' object"

    source = source.source if source.hasOwnProperty 'source'
    source.resolve   ?= ->
    source.construct ?= (x) -> x
    source.predicate ?= -> true
      
    super
    Object.defineProperties this,
      source:   value: source
      binding:  value: source.binding, writable: true
      resolved: value: false, writable: true
      exprs: get: (-> @elements.filter (x) -> x instanceof Expression ).bind this
    
  resolve: ->
    return if @resolved is true
    @debug? "resolving #{@kind} Expression..."
    @source.resolve.apply this, arguments
    @elements.forEach (x) -> x.resolve arguments...
    # perform final scoped constraint validation
    for kind, constraint of @scope when constraint in [ '1', '1..n' ]
      unless @hasOwnProperty kind
        throw @error "constraint violation for required '#{kind}' = #{constraint}"
    @resolved = true
    return this
    
  bind: (data) ->
    return unless data instanceof Object
    if data instanceof Function
      @binding = data
      return this

    @resolve() unless @resolved
    for key, binding of data      
      try @locate(key).bind binding
      catch e
        throw e if e.name is 'ExpressionError'
        throw @error "failed to bind to #{key}", e
    return this

  eval: (data, opts={}) ->
    opts.adaptive ?= true
    @resolve() unless @resolved
    data = @source.construct.call this, data
    unless @source.predicate.call this, data
      throw @error "predicate validation error during eval", data
    if opts.adaptive
      @once 'changed', arguments.callee.bind(this, data)
    @emit 'eval', data
    return data

module.exports = Expression
