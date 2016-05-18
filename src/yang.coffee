#
# Yang - bold outward facing expression and interactive manifestation
#
# represents a YANG schema expression (with nested children)

# external dependencies
parser = require 'yang-parser'
indent = require 'indent-string'
events = require 'events'

# local dependencies
Expression = require './expression'

class Yang extends Expression
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  ###
  # The `constructor` performs recursive parsing of passed in
  # statement and sub-statements.
  #
  # It performs semantic and contextual validations on the provided
  # schema and returns the final JS object tree structure.
  #
  # Accepts: string or JS Object
  # Returns: this
  ###
  constructor: (schema, parent) ->
    unless parent instanceof Expression
      throw @error "Yang must always be created from a parent Expression";
    super parent

    try
      schema = (parser.parse schema) if typeof schema is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = schema.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "invalid YANG syntax detected", offender

    unless schema instanceof Object
      throw @error "must pass in proper YANG schema"

    @kw = ([ schema.prf, schema.kw ].filter (e) -> e? and !!e).join ':'
    @origin = @resolve 'extension', @kw
    unless (@origin instanceof Expression)
      throw @error "encountered unknown extension '#{@kw}'", schema

    @arg = schema.arg if !!schema.arg
    if @arg? and not (@origin.resolve 'argument')?
      throw @error "cannot contain argument for extension '#{@kw}'", schema

    if (@origin.resolve 'scope')?
      @key = [ @kw, @arg ].filter (e) -> !!e
    else
      @key = [ @kw ]

    # merge sub-statement YANG expressions
    @merge schema.substmts...

    # construct this YANG expression from origin
    try
      (@origin.resolve 'construct')?.call this
    catch e
      console.error e
      throw @error "failed to construct '#{@kw} #{@arg}", this

    @created = true

    # do we REALLY need this here?
    if @map.extension?
      console.debug? "[Yang:merge:#{@arg}] found #{Object.keys(@map.extension)} new extension(s)"

  # updates internal @map with additional schema definitions
  #
  # accepts: one or more YANG text schema, JS object, or an instance of Yang
  # returns: this Yang instance with updated map
  merge: (schema..., override=false) ->
    unless typeof override is 'boolean'
      schema.push override
      override = false
    return this unless schema.length > 0

    console.debug? "[Yang:merge:#{@key}] processing #{schema.length} sub-statement(s)"
    schema
    .filter  (x) -> x? and !!x
    .forEach (x) =>
      try
        x = new Yang x, this unless x instanceof Yang
      catch e
        console.warn e
        return
      console.debug? "[Yang:merge:#{@key}] #{x.key} " + if x.map? then "{ #{Object.keys x.map} }" else ''
      [ prf..., kw ] = x.kw.split ':'
      unless (@origin.resolve 'scope', x.kw)? or (@origin.resolve 'scope', kw)?
        throw @error "scope violation - invalid '#{x.kw}' extension found", this
      super x, override

    # perform constraint validation
    for kw, constraint of (@origin.resolve 'scope') ? {}
      [ min, max ] = constraint.split '..'
      min = (Number) min
      max = switch
        when !!max and max isnt 'n' then (Number) max
        else undefined
      exists = @resolve kw
      count = switch
        when not exists? then 0
        when exists.constructor is Object then Object.keys(exists).length
        when exists.constructor is Array  then exists.length
        else 1
      unless (not min? or count >= min) and (not max? or count <= max)
        throw @error "constraint violation for '#{kw}' (#{count} != #{constraint})"

    @emit 'change' if @created is true
    return this

  # converts back to YANG schema string
  toString: (opts={}) ->
    opts.space ?= 2 # default 2 spaces
    s = @kw
    argument = @origin.resolve 'argument'
    if argument?
      s += ' ' + switch
        when argument.value? then "'#{@arg}'"
        when argument.text?
          "\n" + (indent '"'+@arg+'"', ' ', opts.space)
        else @arg

    elems = @expressions().map (x) -> x.toString opts
    if elems.length
      s += " {\n" + (indent (elems.join "\n"), ' ', opts.space) + "\n}"
    else
      s += ';'
    return s

  validate: (data) ->
    validate = @origin.resolve 'validate'
    return false unless validate instanceof Function
    (validate.call this, data)

  ##
  # The below Element class is used for 'transform'
  ##
  class Element
    class ElementError extends Error
      constructor: (msg, context) ->
        res = super msg
        res.context = context
        return res

    constructor: (yang, data) ->
      unless yang instanceof Yang
        throw ElementError "cannot create a new #{@constructor.name} without a valid YANG schema", this

      yang.transform this

      # unless schema.validate data
      #   throw @error "passed in data failed to validate schema"

      if data? then switch typeof data
        when 'object' then @[k] = v for own k, v of data when k of this
        else @__value__ = data

  transform: (obj, opts={}) ->
    return new Element this, obj unless obj instanceof Element

    Object.defineProperty obj, '__value__',
      writable: true
      value: yang.default

    meta = {}
    @expressions().forEach (x) ->
      [ ..., key ] = x.key
      console.debug? "defining #{key} as a new bound Element"

      prop = x.origin.resolve 'element'
      if prop?
        elem = Element.bind null, x
        elem[k] = v for own k, v of prop
        elem.configurable = (x.origin.resolve 'config')?.arg isnt false
        if elem.get? or elem.set?
          elem._ = (x.origin.resolve 'default')?.arg
          elem.get = elem.get.bind elem if elem.get instanceof Function
          elem.set = elem.set.bind elem if elem.set instanceof Function
        else
          elem.value = (x.origin.resolve 'default')?.arg
          elem.writable = true
        Object.defineProperty obj, key, elem
      else
        meta[key] = x.arg
    Object.defineProperty obj, '__meta__', value: meta

    @once 'change', arguments.callee.bind this, obj
    return obj

module.exports = Yang
