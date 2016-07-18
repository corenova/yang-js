# expression - cascading symbolic definitions

events = require 'events'
path   = require 'path'

class Expression
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (kind, tag, opts={}) ->
    unless kind? and opts instanceof Object
      throw @error "must supply 'kind' and 'opts' to create a new Expression"
      
    Object.defineProperties this,
      kind:        value: kind, enumerable: true
      tag:         value: tag,  enumerable: true, writable: true
      root:        value: (opts.root is true or not opts.parent?)
      scope:       value: opts.scope
      argument:    value: opts.argument, writable: true
      parent:      value: opts.parent, writable: true
      represent:   value: opts.represent, writable: true
      resolve:     value: opts.resolve   ? ->
      construct:   value: opts.construct ? (x) -> x
      predicate:   value: opts.predicate ? -> true
      compose:     value: opts.compose, writable: true
      convert:     value: opts.convert, writable: true # should re-consider...
      bindings:    value: opts.bindings ? []
      expressions: get: (->
        (v for own k, v of this when k of (@scope ? {}))
        .reduce ((a,b) -> switch
          when b instanceof Expression then a.concat b
          when b instanceof Array
            a.concat b.filter (x) -> x instanceof Expression
          else a
        ), []
      ).bind this
      _events: writable: true # make this invisible

  clone: ->
    (new Expression @kind, @tag, this)
    .extends @expressions.map (x) -> x.clone()

  bind: (data) ->
    return unless data instanceof Object
    if data instanceof Function
      @bindings.push data
      return this
    (@locate key)?.bind binding for key, binding of data
    return this

  eval: (data, opts={}) ->
    opts.adaptive ?= true
    data = @construct data
    unless @predicate data
      throw @error "predicate validation error during eval", data
    if opts.adaptive
      @once 'extended', arguments.callee.bind(this, data)
    @emit 'eval', data
    return data

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

    unless @scope?
      @[expr.kind] = expr
    else
      unless expr.kind of @scope
        if expr.scope?
          throw @error "scope violation - invalid '#{expr.kind}' extension found"
        else
          @scope[expr.kind] = '*' # this is hackish...

      switch @scope[expr.kind]
        when '0..n', '1..n', '*'
          unless @hasOwnProperty expr.kind
            Object.defineProperty this, expr.kind,
              enumerable: true
              value: [ expr ]
          else @[expr.kind].push expr
        when '0..1', '1'
          unless @hasOwnProperty expr.kind
            Object.defineProperty this, expr.kind,
              enumerable: true
              value: expr
          else if expr.kind is 'argument'
            @[expr.kind] = expr
          else
            throw @error "constraint violation for '#{expr.kind}' - cannot define more than once"
        else
          throw @error "unrecognized scope constraint defined for '#{expr.kind}' with #{@scope[expr.kind]}"

  locate: (key, rest...) ->
    return this unless typeof key is 'string' and !!key
    if (/^\//.test key) and not @root
      return @parent.locate key
      
    if arguments.length is 1
      key  = path.normalize(key).replace /\s/g, ''
      keys = key.split('/').filter (e) -> !!e
      return @locate keys... if keys.length > 1

    if /^\[.*\]$/.test(key)
      key = key.replace /^\[(.*)\]$/, '$1'
      [ kind..., tag ]  = key.split ':'
      [ tag, selector ] = tag.split '='
    else
      [ prf..., tag ]   = key.split ':'
      [ tag, selector ] = tag.split '='

    # TODO: need to do prf matching
      
    for k, v of this when v instanceof Array
      continue if kind?.length and k isnt kind[0]
      for expr in v when expr.tag is tag
        expr.selector = selector
        return expr if rest.length is 0
        return expr.locate rest...
    return undefined
      
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
    prefix = while (node = node.parent) and node.root isnt true
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

  debug: if console.debug? then (msg) -> console.debug "[#{@kind}/#{@tag}] #{msg}"

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
