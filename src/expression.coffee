# expression - cascading symbolic definitions

traverse = require 'traverse'
events   = require 'events'

tokenize = (keys...) ->
  [].concat (keys.map (x) -> ((x?.split? '.')?.filter (e) -> !!e) ? [])...

copy = (dest={}, sources..., append=false) ->
  unless typeof append is 'boolean'
    sources.push append
    append = false
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
        when append is true and dest[p]?
          unless dest[p] instanceof Object
            k = dest[p]
            dest[p] = {}
            dest[p][k] = null
          dest[p][src[p]] = null
        else dest[p] = src[p]
  return dest

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

class Expression
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (parent) ->
    Object.defineProperty this, 'parent', value: parent
    Object.defineProperty this, 'map', value: {}

  # returns the 'updated' defined object
  define: (keys..., value) ->
    copy @map, objectify keys..., value
    return this

  clear: (keys...) ->
    # traverse(@map).map (x) ->
    #   if x instanceof Expression and x.key in keys
    #     @remove true
    keys.forEach (key) => delete @map[key]

  # returns merged nested definitions
  resolve: (keys..., opts={}) ->
    unless opts instanceof Object
      keys.push opts
      opts = {}
    return unless keys.length > 0

    # setup default opts
    opts.warn ?= true
    opts.recurse ?= true

    exists = @parent?.resolve? arguments... if opts.recurse is true

    [ keys..., key ] = tokenize keys...
    [ prefix..., key ] = key.split ':'
    keys.unshift prefix...
    keys.push key

    _get = (obj={}, key, rest...) ->
      if (key of obj) and rest.length
        _get obj[key], rest...
      else
        obj[key]

    match = _get @map, keys...
    match = copy exists, match if exists?.constructor is Object
    match ?= exists
    unless match?
      console.debug? "[Expression:resolve] unable to find #{keys.join ':'}" if opts.warn
    return match

  # TODO: should consider a more generic operation for this function...
  locate: (xpath) ->
    return unless inside? and typeof path is 'string'
    if /^\//.test path
      console.warn "[Element:locate] absolute-schema-nodeid is not yet supported, ignoring #{xpath}"
      return
    [ target, rest... ] = path.split '/'

    console.debug? "[Element:locate] locating #{path}"
    if inside.access instanceof Function
      return switch
        when target is '..'
          if (inside.parent.meta 'synth') is 'list'
            @locate inside.parent.parent, rest.join '/'
          else
            @locate inside.parent, rest.join '/'
        when rest.length > 0 then @locate (inside.access target), rest.join '/'
        else inside.access target

    for key, val of inside when val.hasOwnProperty target
      return switch
        when rest.length > 0 then @locate val[target], rest.join '/'
        else val[target]
    console.warn "[Element:locate] unable to find '#{path}' within #{Object.keys inside}"
    return

  merge: (expr, opts={}) ->
    unless expr instanceof Expression
      throw @error "cannot merge a non-Expression into an Expression", expr

    exists = @resolve expr.key[0], recurse: false
    switch
      when exists instanceof Expression then switch opts.constraint
        when '0..1', '1' then @define expr.key..., expr
        else @define expr.key..., [ exists, expr ]
      when exists instanceof Array then exists.push expr
      when exists instanceof Object then switch opts.constraint
        when '0..1', '1'
          @clear expr.key[0]
          @define expr.key..., expr
        else @define expr.key..., expr
      else
        @define expr.key..., expr

    return this

  expressions: (filter...) ->
    el = []
    for k, v of @map when v? and (filter.length is 0 or k in filter)
      switch
        when v instanceof Expression then el.push v
        when v instanceof Array
          el.push (v.filter (x) -> x instanceof Expression)...
        when v instanceof Object
          el.push (b for a, b of v when b instanceof Expression)...
    return el

  error: (msg, context=this) ->
    res = new Error msg
    res.name = "ExpressionError"
    res.context = context
    return res

  # converts to a simple JS object
  toObject: ->
    x = [].concat @key
    if Object.keys(@map).length
      x.push traverse(@map).map (x) ->
        @update x.toObject(), true if x instanceof Expression
    objectify x...

module.exports = Expression
