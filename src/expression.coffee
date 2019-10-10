# expression - evaluable Element

debug = require('debug')('yang:expression')
delegate = require 'delegates'
Element  = require './element'

class Expression extends Element
  #
  # Source delegation
  #
  delegate @prototype, 'source'
    .access 'argument'
    .getter 'scope'
    .getter 'resolve'
    .getter 'transform'
    .getter 'construct'
    .getter 'predicate'
    .getter 'compose'

  delegate @prototype, 'state'
    .access 'binding'
    .access 'resolved'

  @property 'exprs',
    get: -> @children.filter (x) -> x instanceof Expression

  @property 'nodes',
    get: -> @exprs.filter (x) -> x.node is true

  @property 'attrs',
    get: -> @exprs.filter (x) -> x.node is false

  @property 'node',
    get: -> @construct instanceof Function

  @property 'id',
    get: -> @kind + if @tag? then "(#{@tag})" else ''

  constructor: (kind, tag, source) ->
    super kind, tag
    @source = source
    # { @argument } = @source
    BoundExpression = (-> self.eval arguments...)
    self = Object.setPrototypeOf BoundExpression, this
    Object.defineProperties self,
      inspect: value: -> @toJSON()
    delete self.length
    return self

  debug: -> #debug @uri, arguments...

  clone: ->
    copy = super
    copy.convert = @convert if @convert?
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
      
    if data instanceof Function or (@root isnt this and not @nodes.length)
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
  eval: (data, ctx, opts) ->
    @compile() unless @resolved
    if @node is true
      @construct.call this, data, ctx, opts
    else
      @apply data, ctx, opts

  update: (elem) ->
    res = super
    res.binding = elem.binding
    return res

  error: ->
    res = super
    res.message = "[#{@uri}] #{res.message}"
    res.name = 'ExpressionError'
    return res

module.exports = Expression
