#
# Yang - bold outward facing expression and interactive manifestation
#
# represents a YANG schema expression (with nested children)

# external dependencies
parser   = require 'yang-parser'
indent   = require 'indent-string'

# local dependencies
Expression = require './expression'

class Yang extends Expression

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

    # do we need this here?
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

    console.debug? "[Yang:merge:#{@key}] processing #{schema.length} sub-statement(s)"
    schema
    .filter  (x) -> x? and !!x
    .forEach (x) =>
      x = new Yang x, this unless x instanceof Yang
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

    return this

  validate: (data) ->
    validate = @origin.resolve 'validate'
    return false unless validate instanceof Function
    (validate.call this, data)

  transform: (func, opts={}) ->
    return unless func instanceof Function
    params = @expressions()
      .map (x) ->
        [ ..., key ] = x.key
        "#{key}": x.transform func, opts
      .reduce ((a,b) -> a[k] = v for k, v of b; a), {}
    func this, params, opts

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

module.exports = Yang
