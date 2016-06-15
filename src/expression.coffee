# expression - cascading symbolic definitions

promise = require 'promise'
events  = require 'events'
path    = require 'path'

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

    @resolve   = @resolve.bind this
    @construct = @construct.bind this
    @predicate = @predicate.bind this

    @[k] = v for own k, v of opts when k not of this

  eval: (data, opts={}) ->
    opts.adaptive ?= true
    data = @construct data
    unless @predicate data
      throw @error "predicate validation error during eval", data
    if opts.adaptive
      @once 'extended', arguments.callee.bind(this, data)
    return data

  propertize: (key, value, property={}) ->
    unless property instanceof Object
      throw @error "unable to propertize with invalid property params"

    property.configurable ?= true
    property.enumerable   ?= value?
    property.name   = key
    property.expr   = this
    property._value = value # private

    # the setter for the property is called with this = property
    property.set = ((val, force=false) -> switch
      when force is true then @_value = val
      else
        console.debug? "setting #{@name}"
        res = @expr.eval { "#{@name}": val }
        val = res.__[@name]?._value # access bypassing 'getter'
        if @parent? then @expr.update @parent, @name, val
        else @_value = val
    ).bind property

    # the getter for the property is called with this = property
    property.get = ((xpath) -> switch
      when !!xpath and typeof xpath is 'string'
        xpath = path.normalize xpath
        # establish starting 'val'
        val = switch
          when /^\//.test xpath
            val = @parent
            val = val.__.parent while val?.__?.parent?
            val
          when /^\.\.\//.test xpath
            xpath = xpath.replace /^\.\.\//, ''
            @parent
          else
            val = @_value
            
        for key in xpath.match /([^\/^\[]+(?:\[.+\])*)/g when !!key
          break unless val?
          val = switch key
            when '..' then val.__?.parent
            # TODO: fully support XPATH predicates
            when /(.+)\[(.+)\]/
              [ ..., key, predicate ] = /(.+)\[(.+)\]/.exec key
              console.warn "XPATH predicate #{predicate} not yet supported"
              val[key]
            else val[key]
        val
      # when value is a function, we will call it with the current
      # 'property' object as the bound context (this) for the
      # function being called.
      when @_value instanceof Function then switch
        when @_value.computed is true then @_value.call this
        when @_value.async is true
          (args...) => new promise (resolve, reject) =>
            @_value.apply this, [].concat args, resolve, reject
        else @_value.bind this
      when @_value?.constructor is Object and property.static isnt true
        # clean-up properties unknown to the expression
        for own k, v of @_value 
          desc = (Object.getOwnPropertyDescriptor value, k)
          delete @_value[k] if desc.writable
        @_value
      else @_value
    ).bind property

    if value instanceof Object
      # setup direct property access
      unless value.hasOwnProperty '__'
        Object.defineProperty value, '__', writable: true
      value.__ = property

    return property
    
  update: (obj, key, value, opts={}) ->
    return unless obj instanceof Object and key?

    opts.parent = obj
    property = @propertize key, value, opts
          
    # update containing object with this property for reference
    unless obj.hasOwnProperty '__'
      Object.defineProperty obj, '__', writable: true, value: {}
    obj.__[key] = property

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
    node = this
    prefix = while (node = node.parent) and node.kind isnt 'composition'
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
