#
# Yang - bold outward facing expression and interactive manifestation
#
# represents a YANG schema expression (with nested children)

# external dependencies
parser   = require 'yang-parser'
traverse = require 'traverse'
indent   = require 'indent-string'

# local dependencies
Element = require './element'

class Yang extends Element

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
    unless parent instanceof Element
      throw @error "Yang must always be created from a parent Element";
    super parent

    unless schema?
      @scope = @resolve 'extension'
      return this

    try
      schema = (parser.parse schema) if typeof schema is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = schema.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "invalid YANG syntax detected", offender

    unless schema instanceof Object
      throw @error "must pass in proper YANG schema"

    @key = ([ schema.prf, schema.kw ].filter (e) -> e? and !!e).join ':'
    ext = @resolve 'extension', @key
    unless (ext instanceof Object)
      throw @error "encountered unknown extension '#{@key}'", schema

    # inherit the extension defs into current object
    { @argument, @scope } = switch
      when ext instanceof Yang then ext.extract 'argument', 'scope'
      else ext
    @scope ?= {}

    @arg = schema.arg if !!schema.arg
    if @arg? and not @argument?
      throw @error "cannot contain argument for extension '#{@key}'", schema

    # merge sub-statement YANG expressions
    @merge schema.substmts...

    # preprocess this YANG expression
    ext.preprocess?.call this, @origin

    # do we need this here?
    if @map.extension?
      console.debug? "[Yang:merge:#{@arg}] found #{Object.keys(@map.extension)} new extension(s)"

  # updates internal @map with additional schema definitions
  #
  # accepts: one or more YANG text schema, JS object, or an instance of Yang
  # returns: this Yang instance with updated map
  merge: (schemas...) ->
    console.debug? "[Yang:merge:#{@key}/#{@arg}] processing #{schemas.length} sub-statement(s)"
    schemas
    .filter (x) -> x? and !!x
    .forEach (x) =>
      x = new Yang x, this unless x instanceof Yang
      console.debug? "[Yang:merge:#{@key}/#{@arg}] #{x.key} #{x.arg} " + if x.map? then "{ #{Object.keys x.map} }" else ''
      exists = @get x.key
      [ prf..., kw ] = x.key?.split ':'
      constraint = @scope[x.key] ? @scope[kw]
      valid = switch constraint
        when undefined
          throw @error "scope violation - invalid '#{x.key}' extension found", this
        when '0..1', '1' then not exists?
        else true
      unless valid
        throw @error "constraint violation for '#{x.key}' (#{constraint})"

      switch
        when Object.keys(x.scope).length then @set x.key, x.arg, x
        when exists? and exists instanceof Array then exists.push x
        when exists? then @set x.key, [ exists, x ]
        else @set x.key, x

  # TODO: should consider a more generic operation for this function...
  locate: (inside, path) ->
    return unless inside? and typeof path is 'string'
    if /^\//.test path
      console.warn "[Yang:locate] absolute-schema-nodeid is not yet supported, ignoring #{path}"
      return
    [ target, rest... ] = path.split '/'

    console.debug? "[Yang:locate] locating #{path}"
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
    console.warn "[Yang:locate] unable to find '#{path}' within #{Object.keys inside}"
    return

  create: (data) ->

  validate: (data) ->

  transform: ->

  elements: ->
    el = []
    for k, v of @map when k of @scope and v?
      switch
        when v instanceof Yang then el.push v
        when v.constructor is Object
          el.push (b for a, b of v when b instanceof Yang)...
    return el

  # converts back to YANG schema string
  toString: (opts={}) ->
    opts.space ?= 2 # default 2 spaces
    s = @key
    if @argument?
      s += ' ' + switch
        when @argument.value? then "'#{@arg}'"
        when @argument.text?
          "\n" + (indent '"'+@arg+'"', ' ', opts.space)
        else @arg

    elems = @elements().map (x) -> x.toString opts
    if elems.length
      s += " {\n" + (indent (elems.join "\n"), ' ', opts.space) + "\n}"
    else
      s += ';'
    return s

  # converts to a simple JS object
  toObject: ->
    x = [ @key ]
    x.push @arg if @arg?
    if Object.keys(@map).length
      x.push traverse(@map).map (x) ->
        @update x.toObject(), true if x instanceof Yang
    @objectify x...

module.exports = Yang
