# origin - cascading symbol definitions

class Origin

  constructor: (@origin) -> @map = {}

  # returns the 'updated' defined object
  define: (keys..., value) ->
    exists = @resolve keys..., warn: false
    definition = @objectify (keys.join '.'), switch
      when not exists?             then value
      when exists.constructor is Object
        @copy exists, value
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

    extract = (obj={}, key, rest...) ->
      if (key of obj) and rest.length
        extract obj[key], rest...
      else
        obj[key]

    match = extract @map, keys...
    match = @copy exists, match if exists?.constructor is Object
    match ?= exists
    unless match?
      console.debug? "[Origin:resolve] unable to find #{keys.join ':'}" if opts.warn
    return match

  # explicitly 'set' a value into the internal 'map'
  set: (keys..., value) ->
    obj = @objectify (keys.join '.'), value
    @copy @map, obj if obj instanceof Object;
    return this

  copy: (dest={}, src, append=false) ->
    for p of src
      switch
        when src[p]?.constructor is Object
          dest[p] ?= {}
          unless dest[p] instanceof Object
            k = dest[p]
            dest[p] = {}
            dest[p][k] = null
          arguments.callee dest[p], src[p], append
        when append is true and dest[p]?
          unless dest[p] instanceof Object
            k = dest[p]
            dest[p] = {}
            dest[p][k] = null
          dest[p][src[p]] = null
        else dest[p] = src[p]
    return dest

  tokenize = (key) -> ((key?.split? '.')?.filter (e) -> !!e) ? []

  objectify: (key, val) ->
    return key if key instanceof Object
    composite = tokenize key
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

  # TODO: should consider a more generic operation for this function...
  locate: (inside, path) ->
    return unless inside? and typeof path is 'string'
    if /^\//.test path
      console.warn "[Origin:locate] absolute-schema-nodeid is not yet supported, ignoring #{path}"
      return
    [ target, rest... ] = path.split '/'

    console.debug? "[Origin:locate] locating #{path}"
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
    console.warn "[Origin:locate] unable to find '#{path}' within #{Object.keys inside}"
    return

module.exports = Origin
