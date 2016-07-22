# expression - cascading symbolic definitions

events = require 'events'

class Expression
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (kind, tag, parent) ->
    unless kind?
      throw @error "must supply 'kind' to create a new Expression"
      
    Object.defineProperties this,
      kind:    value: kind, enumerable: true
      tag:     value: tag,  enumerable: true, writable: true
      
      parent:  value: parent
      scope:   writable: true, configurable: true
      binding: writable: true
      
      expressions:
        get: (->
          (v for own k, v of this).reduce ((a,b) -> switch
            when b instanceof Expression then a.concat b
            when b instanceof Array
              a.concat b.filter (x) -> x instanceof Expression
            else a
          ), []
        ).bind this
        
      '*': get: (-> @expressions ).bind this
      
      _events: writable: true # make this invisible

  clone: ->
    (new Expression @kind, @tag, this)
    .extends @expressions.map (x) -> x.clone()

  eval: (data, opts={}) ->
    opts.adaptive ?= true
    data = @evaluate data
    unless @predicate data
      throw @error "predicate validation error during eval", data
    if opts.adaptive
      @once 'changed', arguments.callee.bind(this, data)
    @emit 'eval', data
    return data

  # primary mechanism for defining sub-expressions to become part of the schema
  extends: (exprs...) ->
    exprs = ([].concat exprs...).filter (x) -> x? and !!x
    return this unless exprs.length > 0
    exprs.forEach (expr) => @merge expr
    @emit 'changed', exprs
    return this

  # merges an Expression into current Expression
  merge: (expr) ->
    unless expr instanceof Expression
      throw @error "cannot merge a non-Expression into an Expression", expr

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
              value: []
            Object.defineProperty @[expr.kind], 'tags',
              value: []
          unless expr.tag in @[expr.kind].tags
            @[expr.kind].tags.push expr.tag
            @[expr.kind].push expr
          else
            throw @error "constraint violation for '#{expr.kind} #{expr.tag}' - cannot define more than once"
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
          
    return expr

  # performs conditional merge based on existence
  update: (expr) ->
    unless expr instanceof Expression
      throw @error "cannot update a non-Expression into an Expression", expr

    #@debug? "update with #{expr.kind}/#{expr.tag}"
    exists = @match expr.kind, expr.tag
    return @merge expr unless exists?

    #@debug? "update #{exists.kind} in-place for #{expr.expressions.length} expressions"
    exists.update target for target in expr.expressions
    # TODO: should ensure uniqueness check...
    #exists.bindings.push expr.bindings...
    return exists

  # Looks for matching Expressions down the sub-expressions using YPATH notation
  locate: (ypath) ->
    return unless typeof ypath is 'string' and !!ypath
    ypath = ypath.replace /\s/g, ''
    if (/^\//.test ypath) and this isnt @root
      return @root.locate ypath
    [ key, rest... ] = ypath.split('/').filter (e) -> !!e
    return this unless key?
    
    if key is '..'
      return unless not @root
      return @parent.locate rest.join('/')

    @debug? "locate #{key} with '#{rest}'"

    # TODO: should consider a different semantic expression to match
    # explicit 'kind'
    if /^\[.*\]$/.test(key)
      key = key.replace /^\[(.*)\]$/, '$1'
      [ kind..., tag ]  = key.split ':'
      [ tag, selector ] = tag.split '='
      kind = kind[0] if kind?.length
    else
      [ tag, selector ] = key.split '='
      kind = '*'

    match = @match kind, tag
    return switch
      when rest.length is 0 then match
      else match?.locate rest.join('/')
      
  # Looks for matching Expressions using kind and tag (up the hierarchy)
  lookup: (kind, tag) ->
    res = switch
      when this not instanceof Object then undefined
      when this instanceof Expression then @match kind, tag
      else Expression::match.call this, kind, tag
    res ?= Expression::lookup.apply @parent, arguments if @parent?
    return res

  # Looks for a matching Expression in immediate sub-expressions
  match: (kind, tag) ->
    return unless this instanceof Object # do we need this?
    return unless kind? and @hasOwnProperty kind
    return @[kind] unless tag?

    match = @[kind]
    match = [ match ] unless match instanceof Array
    for expr in match when expr instanceof Expression
      key = if expr.tag? then expr.tag else expr.kind
      return expr if tag is key
    return undefined

  error: (msg, context=this) ->
    res = new Error msg
    res.name = "ExpressionError"
    res.context = context
    return res

  debug: if console.debug? then (msg) -> console.debug "[#{@kind}/#{@tag}] #{msg}"

  # converts to a simple JS object
  toObject: ->
    @debug "converting #{@kind} toObject with #{@expressions.length}"
    
    sub =
      @expressions
        .filter (x) => x.parent is this
        .reduce ((a,b) ->
          for k, v of b.toObject()
            if a[k] instanceof Object
              a[k][kk] = vv for kk, vv of v if v instanceof Object
            else
              a[k] = v
          return a
        ), {}

    return "#{@kind}": switch
      when Object.keys(sub).length > 0
        if @tag? then "#{@tag}": sub else sub
      else @tag

module.exports = Expression
