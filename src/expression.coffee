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
      throw @error "validation error for #{@kind} #{@tag}", data
    if opts.adaptive
      @once 'extended', arguments.callee.bind(this, data)
    return data

  update: (obj, key, value, opts={}) ->
    return unless obj instanceof Object and key?

    opts.enumerable ?= true
    
    if value?.constructor is Object
      # clean-up non getter/setter properties
      for own k, v of value when 'value' of (Object.getOwnPropertyDescriptor value, k)
        delete value[k]

    property = 
      enumerable: opts.enumerable
      set: ((val, force=false) -> value = switch
        when force is true then val
        else (@eval "#{key}": val)?[key]
      ).bind this
      get: (xpath) -> switch
        when xpath? then null
        when value instanceof Function
          (args...) -> new promise (resolve, reject) ->
            value.apply obj, [].concat args, resolve, reject
        when value instanceof Array
          [].concat value # return a copy array to protect value
        else value
      origin: this
        
    # save this property definition
    unless obj.hasOwnProperty '__yang__'
      Object.defineProperty obj, '__yang__', value: {}
    obj.__yang__[key] = property
    
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

  contains: (kind, tag) -> (@lookup kw, arg, false)?

  error: (msg, context=this) ->
    res = new Error msg
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
