# expression - evaluable Element

debug = require('debug')('yang:expression') if process.env.DEBUG?
delegate = require 'delegates'
clone    = require 'clone'
Element  = require './element'

class Expression extends Element

  #
  # Source delegation
  #
  delegate @prototype, 'source'
    .getter 'resolve'
    .getter 'transform'
    .getter 'construct'
    .getter 'predicate'
    .getter 'compose'

  @property 'exprs',
    get: -> @elements.filter (x) -> x instanceof Expression

  @property 'id',
    get: -> @kind + if @tag? then "(#{@tag})" else ''

  constructor: ->
    super
    { @argument } = @source
    BoundExpression = (-> self.eval arguments...)
    self = Object.setPrototypeOf BoundExpression, this
    Object.defineProperties self,
      inspect: value: -> @toJSON()
    delete self.length
    return self

  clone: ->
    copy = super
    copy.resolved = @resolved
    copy.binding  = @binding if @binding?
    copy.convert  = @convert if @convert?
    # propagate binding function to clones (and their clones) if node element
    if @node then @once 'bind', (func) ->
      copy.binding ?= func
      copy.emit 'bind', func
    return copy

  compile: ->
    debug? "[#{@trail}] compile enter... (#{@resolved})"
    @emit 'compile:before', arguments
    @resolve?.apply this, arguments unless @resolved
    if @tag? and not @argument?
      throw @error "cannot contain argument '#{@tag}' for expression '#{@kind}'"
    if @argument? and not @tag?
      throw @error "must contain argument '#{@argument}' for expression '#{@kind}'"
    debug? "[#{@trail}] has sub-expressions: #{@exprs.map (x) -> x.kind}" if @exprs.length
    @exprs.forEach (x) -> x.compile()
    @resolved = true
    @emit 'compile:after'
    debug? "[#{@trail}] compile: ok"
    return this
      
  bind: (key..., data) ->
    return this unless data instanceof Object
    return @bind("#{key[0]}": data) if key.length
      
    if data instanceof Function
      debug? "bind: registering function at #{@trail}"
      @binding = data
      @emit 'bind', data
      return this
    for key, binding of data      
      try @locate(key).bind binding
      catch e
        throw e if e.name is 'ExpressionError'
        throw @error "failed to bind to '#{key}' (schema-path not found)", e
    return this

  # internally used to apply the expression to the passed in data
  apply: (data, ctx) ->
    @compile() unless @resolved
    debug? "[#{@trail}] applying data to schema expression:"
    debug? this
    
    @emit 'apply:before', data
    if @transform?
      data = @transform.call this, data, ctx
    else
      data = expr.eval data, ctx for expr in @exprs when data?

    try @predicate?.call this, data
    catch e
      debug? data
      throw @error "predicate validation error: #{e}", data
    @emit 'apply:after', data
    return data

  # evalute the provided data
  # when called without ctx for a node, perform a deep clone
  eval: (data, ctx) ->
    @compile() unless @resolved
    debug? "[#{@trail}] eval"
    debug? this
    if @node is true
      data = clone(data) unless ctx?
      @construct.call this, data, ctx
    else @apply data, ctx

  update: (elem) ->
    res = super
    res.binding = elem.binding
    return res

  error: ->
    res = super
    res.name = 'ExpressionError'
    return res

module.exports = Expression
