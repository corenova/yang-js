# expression - evaluable Element

debug    = require('debug')('yang:expression')
#clone    = require 'clone'
delegate = require 'delegates'
Element  = require './element'

class Expression extends Element

  @property 'exprs',
    get: -> @elements.filter (x) -> x instanceof Expression
  
  #
  # Source delegation
  #
  delegate @prototype, 'source'
    .access 'argument'
    .getter 'resolve'
    .getter 'transform'
    .getter 'construct'
    .getter 'predicate'
    .getter 'compose'

  clone: ->
    copy = super
    copy.resolved = @resolved
    copy.convert  = @convert if @convert?
    return copy

  compile: ->
    #debug "[#{@trail}] compile enter... (#{@resolved})"
    @emit 'compile:before', arguments
    @resolve?.apply this, arguments unless @resolved
    if @tag? and not @argument?
      throw @error "cannot contain argument '#{@tag}' for expression '#{@kind}'"
    if @argument? and not @tag?
      throw @error "must contain argument '#{@argument}' for expression '#{@kind}'"
    @exprs.forEach (x) -> x.compile arguments...
    @resolved = true
    @emit 'compile:after'
    #debug "[#{@trail}] compile: ok"
    return this
      
  bind: (key..., data) ->
    return unless data instanceof Object
    return @bind("#{key[0]}": data) if key.length
      
    if data instanceof Function
      debug "bind: registering function"
      @binding = data
      return this
    for key, binding of data      
      try @locate(key).bind binding
      catch e
        throw e if e.name is 'ExpressionError'
        throw @error "failed to bind to '#{key}' (schema-path not found)", e
    return this

  # internally used to apply the expression to the passed in data
  apply: (data, ctx={}) ->
    @compile()
    @emit 'apply:before', data
    debug 'applying data to schema expression:'
    debug this

    if @transform?
      data = @transform.call this, data, ctx
    else
      data = expr.eval data, ctx for expr in @exprs when data?

    unless not @predicate? or @predicate.call this, data
      debug data
      throw @error "predicate validation error during apply", data

    @emit 'apply:after', data
    return data

  eval: (data, ctx={}) ->
    @compile()
    debug "[#{@trail}] eval"
    if @node is true then @construct.call this, data, ctx
    else @apply data, ctx

  error: ->
    res = super
    res.name = 'ExpressionError'
    return res

module.exports = Expression
