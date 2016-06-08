# expression - cascading symbolic definitions

promise = require 'promise'
events  = require 'events'

class Expression extends Function
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (keyword, opts={}) ->
    unless keyword? and opts instanceof Object
      throw @error "must supply 'keyword' and 'data' to create a new Expression"

    Object.defineProperties this,
      kw:        value: keyword
      argument:  value: opts.argument, writable: true
      parent:    value: opts.parent
      scope:     value: opts.scope
      resolve:   value: opts.resolve   ? ->
      predicate: value: opts.predicate ? -> true
      construct: value: opts.construct ? (x) -> x
      state: writable: true
      expressions: value: []

    # Expression is a Function Property
    expr = (super 'return this.eval.apply(this,arguments)').bind this
    expr.source = this
    @emit 'created', expr
    return expr

  eval: (data) ->
    data = @construct.call this, data
    unless @predicate.call this, data
      throw @error "validation error for #{@kw} #{@arg}", data
    return data

  update: (obj, key, value) ->
    return unless obj? and key?
    switch
      when value.constructor is Object
        # clean-up non getter/setter properties
        for own k, v of value when 'value' of Object.getOwnPropertyDescriptor value, k
          delete value[k]
    Object.defineProperty obj, key,
      enumerable: true
      set: ((val) -> value = (@eval "#{key}": val)?[key]).bind this
      get: (xpath) -> switch
        when xpath? then null
        when value instanceof Function
          (args...) -> new promise (resolve, reject) ->
            value.apply obj, [].concat args, resolve, reject
        when value instanceof Array
          [].concat value # return a copy array to protect value
        else value

  # primary mechanism for defining sub-expressions
  extends: (exprs...) ->
    _extend = (key, expr) =>
      unless expr instanceof Expression
        throw @error "cannot extend a non-Expression into an Expression", expr

      console.debug? "extending #{key}"
      if not @scope? or key is 'argument'
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
    
    exprs.forEach (item) => switch
      when item instanceof Function
        _extend item.source.kw, item.source
        @expressions.push item
      when item instanceof Object
        for own k, v of item when v instanceof Function
          _extend k, v.source
          @expressions.push v
      
    @emit 'extended', this
    return this

  # recursively look for matching Expression
  lookup: (kw) ->
    return unless kw? and this instanceof Object
    return @[kw] if @hasOwnProperty kw
    return @parent?.lookup? arguments...

  error: (msg, context=this) ->
    res = new Error msg
    res.name = "ExpressionError"
    res.context = context
    return res

  # converts to a simple JS object
  # 
  copy = (dest={}, sources...) ->
    for src in sources
      for p of src
        switch
          when src[p]?.constructor is Object
            dest[p] ?= {}
            unless dest[p] instanceof Object
              k = dest[p]
              dest[p] = {}
              dest[p][k] = null
            arguments.callee dest[p], src[p]
          else dest[p] = src[p]
    return dest

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

  toObject: ->
    console.log this.expressions
    sub = @expressions.reduce ((a,b) -> copy a, b.toObject()), {}
    if Object.keys(sub).length
      objectify @kw, @arg, sub
    else
      objectify @kw, @arg

module.exports = Expression
