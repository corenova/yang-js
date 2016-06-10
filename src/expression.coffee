# expression - cascading symbolic definitions

promise = require 'promise'
events  = require 'events'

class Expression
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (tag, opts={}) ->
    unless tag? and opts instanceof Object and opts.kind?
      throw @error "must supply 'tag' and 'opts.kind' to create a new Expression"
    tag = undefined unless !!tag
    Object.defineProperties this,
      kind:        value: opts.kind, enumerable: true
      tag:         value: tag, enumerable: true, writable: true
      parent:      value: opts.parent
      scope:       value: opts.scope
      resolve:     value: opts.resolve   ? ->
      predicate:   value: opts.predicate ? -> true
      construct:   value: opts.construct ? (x) -> x
      represent:   value: opts.represent
      expressions: value: []
      _events: writable: true

    @[k] = v for own k, v of opts when k not of this

  eval: (data, opts={}) ->
    opts.adaptive ?= true
    data = @construct.call this, data
    unless @predicate.call this, data
      throw @error "validation error during eval", data
    if opts.adaptive
      @once 'extended', arguments.callee.bind(this, data)
    return data

  clean: (obj) ->
    return obj unless obj?.constructor is Object
    # clean-up non getter/setter properties
    for own k, v of obj when 'value' of (Object.getOwnPropertyDescriptor obj, k)
      delete obj[k]
    return obj
    
  update: (obj, key, value, opts={}) ->
    return unless obj instanceof Object and key?
    opts.enumerable ?= value?
    value = @clean value
    property =
      configurable: true
      enumerable: opts.enumerable
      set: ((val, force=false) -> switch
        when force is true then value = val
        else
          val = expr.eval val for expr in @expressions
          unless @predicate.call this, val
            throw @error "validation error", val
          @update obj, key, val
      ).bind this
      get: ((xpath) -> switch
        when xpath?
          unless typeof xpath is 'string'
            throw @error "XPATH must be a string"
          # check if absolute path? shouldn't support it...
          val = value
          val = val[k] for k in xpath.split '/' when !!k
          val
        when value instanceof Function then switch
          when value.computed is true then value.call this, obj
          else (args...) -> new promise (resolve, reject) ->
            value.apply obj, [].concat args, resolve, reject
        else value
      ).bind this
      origin: this

    # save this property definition
    if value instanceof Object
      unless value.hasOwnProperty '..'
        Object.defineProperty value, '..', writable: true
      unless value.hasOwnProperty '$'
        Object.defineProperty value, '$', writable: true
      value['..'] = obj # traverse up the tree
      value.$ = property
        
    unless obj.hasOwnProperty '$'
      Object.defineProperty obj, '$', writable: true, value: {}
    obj.$[key] = property

    # attach property and return updated obj
    Object.defineProperty obj, key, property

  # primary mechanism for defining sub-expressions
  extends: (exprs...) ->
    return unless exprs.length > 0
    exprs.forEach (item) => switch
      when item instanceof Expression
        @_extend item.kind, item
      when item instanceof Object
        for own k, v of item when v instanceof Expression
          @_extend k, v
    @emit 'extended', this
    return this

  # private helper, should not be called directly
  _extend: (key, expr) ->
    unless expr instanceof Expression
      throw @error "cannot extend a non-Expression into an Expression", expr

    if not @scope?
      @[key] = expr
      return

    unless key of @scope
      throw @error "scope violation - invalid '#{key}' extension found"

    switch @scope[key]
      when '0..n', '1..n'
        unless @hasOwnProperty key
          Object.defineProperty this, key,
            enumerable: true
            value: [ expr ]
        else @[key].push expr
      when '0..1', '1'
        unless @hasOwnProperty key
          Object.defineProperty this, key,
            enumerable: true
            value: expr
        else
          throw @error "constraint violation for '#{key}' - cannot define more than once"
      else
        throw @error "unrecognized scope constraint defined: #{@scope[key]}"
          
    @expressions.push expr

  # recursively look for matching Expressions using kind and tag
  lookup: (kind, tag, recurse=true) ->
    return unless kind? and this instanceof Object
    unless tag?
      return @[kind] if @hasOwnProperty kind
      return @parent?.lookup? arguments...
      
    [ prefix..., arg ] = tag.split ':'
    if prefix.length and @hasOwnProperty prefix[0]
      return @[prefix[0]].lookup? kind, arg
    else
      if (@hasOwnProperty kind) and @[kind] instanceof Array
        for expr in @[kind] when expr? and expr.tag is arg
          return expr
    return @parent?.lookup? arguments... if recurse is true

  contains: (kind, tag) -> (@lookup kind, tag, false)?

  error: (msg, context=this) ->
    preamble = [ @kind, @tag ].join '/'
    preamble = 'constructor' unless !!preamble
    res = new Error "[#{preamble}] #{msg}"
    res.name = "ExpressionError"
    res.context = context
    return res

  # converts to a simple JS object
  # 
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
