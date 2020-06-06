# expression - evaluable Element

debug = require('debug')('yang:expression')
delegate = require 'delegates'
Element  = require './element'

class Expression extends Element
  #
  # Source delegation
  #
  delegate @prototype, 'source'
    .getter 'scope'
    .getter 'resolve'
    .getter 'transform'
    .getter 'construct'
    .getter 'predicate'
    .getter 'compose'

  delegate @prototype, 'state'
    .access 'binding'
    .access 'resolved'

  @property 'argument',
    get: -> @state.argument ? @source.argument
    set: (value) -> @state.argument = value

  @property 'exprs',
    get: -> @children.filter (x) -> x instanceof Expression

  @property 'nodes',
    get: -> @exprs.filter (x) -> x.node is true

  @property 'attrs',
    get: -> @exprs.filter (x) -> x.node is false

  @property 'node',
    get: -> @construct instanceof Function

  @property '*', get: -> @nodes

  constructor: (kind, tag, source) ->
    super kind, tag
    @source = source
    evaluate = (-> self.eval arguments...)
    self = Object.setPrototypeOf evaluate, this
    Object.defineProperties self,
      inspect: value: -> @toJSON()
    delete self.length # TODO: this may not work for Edge browser...
    return self

  debug: -> #debug @uri, arguments...

  clone: ->
    copy = super arguments...
    copy.convert = @convert if @convert?
    return copy

  compile: ->
    @debug "[compile] enter... (#{@resolved})"
    @emit 'compiling', arguments
    @resolve?.apply this, arguments unless @resolved
    if @tag? and not @argument
      throw @error "cannot contain argument '#{@tag}' for expression '#{@kind}'"
    if @argument and not @tag?
      throw @error "must contain argument '#{@argument}' for expression '#{@kind}'"
    @debug "has sub-expressions: #{@exprs.map (x) -> x.kind}" if @exprs.length
    @exprs.forEach (x) -> x.compile()
    @resolved = true
    @emit 'compiled'
    @debug "[compile] done"
    return this
      
  bind: (data) ->
    if data?
      @debug "[bind] registering #{typeof data} binding"
      @binding = data
      @emit 'bind', data
    else # allows unbinding...
      @debug "[bind] removing prior #{typeof @binding} binding"
      @binding = undefined
    return this

  # internally used to apply the expression to the passed in data
  apply: (data, ctx, opts) ->
    @compile() unless @resolved
    @emit 'transforming', data
    if @transform?
      data = @transform.call this, data, ctx, opts
    else
      data = expr.eval data, ctx, opts for expr in @exprs when data?

    try @predicate?.call this, data, opts
    catch e
      @debug data
      throw @error "predicate validation error: #{e}", data
    @emit 'transformed', data
    return data

  # evalute the provided data
  eval: (data, ctx, opts) ->
    @compile() unless @resolved
    if @node is true
      data ?= {}
      @construct.call this, data, ctx, opts
    else
      @apply data, ctx, opts

  update: (elem) ->
    res = super arguments...
    res.binding = elem.binding
    return res

  error: ->
    res = super arguments...
    res.message = "[#{@uri}] #{res.message}"
    res.name = 'ExpressionError'
    return res

module.exports = Expression
