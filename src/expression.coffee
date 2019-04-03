# expression - evaluable Element

debug = require('debug')('yang:expression')
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

  debug: -> debug @uri, arguments...

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
    @debug "[compile] enter... (#{@resolved})"
    @emit 'compile:before', arguments
    @resolve?.apply this, arguments unless @resolved
    if @tag? and not @argument?
      throw @error "cannot contain argument '#{@tag}' for expression '#{@kind}'"
    if @argument? and not @tag?
      throw @error "must contain argument '#{@argument}' for expression '#{@kind}'"
    @debug "has sub-expressions: #{@exprs.map (x) -> x.kind}" if @exprs.length
    @exprs.forEach (x) -> x.compile()
    @resolved = true
    @emit 'compile:after'
    @debug "[compile] done"
    return this
      
  bind: (key..., data) ->
    return @bind("#{key[0]}": data) if key.length

    unless data? # allows unbinding...
      @binding = undefined
      return this
      
    if data instanceof Function or not @nodes.length
      @debug "[bind] registering #{typeof data}"
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
  apply: (data, ctx, opts) ->
    @compile() unless @resolved
    @emit 'apply:before', data
    if @transform?
      @debug "[apply] transform data"
      data = @transform.call this, data, ctx, opts
    else
      data = expr.eval data, ctx, opts for expr in @exprs when data?

    try @predicate?.call this, data
    catch e
      @debug data
      throw @error "predicate validation error: #{e}", data
    @emit 'apply:after', data
    return data

  # evalute the provided data
  # when called without ctx for a node, perform a deep clone
  eval: (data, ctx, opts) ->
    @compile() unless @resolved
    if @node is true
      @debug "[eval] construct data node"
      # data = clone(data) unless ctx?
      @construct.call this, data, ctx, opts
    else @apply data, ctx, opts

  update: (elem) ->
    res = super
    res.binding = elem.binding
    return res

  error: ->
    res = super
    res.name = 'ExpressionError'
    return res

module.exports = Expression
