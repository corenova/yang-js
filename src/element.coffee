# element - cascading symbolic node definitions

class Element

  constructor: (@origin) -> @map = {}

  # returns the 'updated' defined object
  define: (keys..., value) ->
    exists = @resolve keys..., warn: false
    definition = @objectify keys..., switch
      when not exists? then value
      when exists.constructor is Object then @copy exists, value
      else
        throw @error "unable to define #{keys.join '.'} due to conflict with existing definition", exists
    @set definition
    return definition

  # returns merged nested definitions
  resolve: (keys..., opts={}) ->
    unless opts instanceof Object
      keys.push opts
      opts = {}
    return unless keys.length > 0

    # setup default opts
    opts.warn ?= true
    opts.recurse ?= true

    exists = @origin?.resolve? arguments... if opts.recurse is true

    [ keys..., key ] = keys
    [ prefix..., key ] = key.split ':'
    keys.unshift prefix...
    keys.push key

    match = @get keys...
    match = @copy exists, match if exists?.constructor is Object
    match ?= exists
    unless match?
      console.debug? "[Element:resolve] unable to find #{keys.join ':'}" if opts.warn
    return match

  # explicitly 'set' a value into the internal 'map'
  set: (keys..., value) ->
    obj = @objectify keys..., value
    @copy @map, obj if obj instanceof Object
    return this

  # explicitly 'get' a value from the internal 'map'
  get: (keys...) ->
    _get = (obj={}, key, rest...) ->
      if (key of obj) and rest.length
        _get obj[key], rest...
      else
        obj[key]
    return _get @map, keys...

  copy: (dest=@map, sources..., append=false) ->
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

  extract: ->
    keys = [].concat arguments...
    return @copy {}, @map unless keys.length > 0
    @copy {}, (keys.map (key) => @objectify key, @resolve key)...

  tokenize = (key) -> ((key?.split? '.')?.filter (e) -> !!e) ? []

  objectify: (keys..., val) ->
    composite = [].concat (keys.map (x) -> tokenize x)...
    unless composite.length
      return val ? {}

    obj = root = {}
    while (k = composite.shift())
      last = r: root, k: k
      root = root[k] = {}
    last.r[last.k] = val
    obj

  error: (msg, context) ->
    res = new Error msg
    res.context = context ? @map
    return res

module.exports = Element
