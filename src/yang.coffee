#
# Yang - bold outward facing expression and interactive manifestation
#
# represents a YANG schema expression (with nested children)

# external dependencies
parser  = require 'yang-parser'
indent  = require 'indent-string'
events  = require 'events'
promise = require 'promise'

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

  ##
  # The below Element class is used for 'transform'
  ##
  class Element
    constructor: (yang, value) ->
      Object.defineProperty this, '__meta__', value: {}

      console.debug? "making new Element with #{yang.length} schemas"
      ([].concat yang).forEach (x) => x.transform? this

      return unless value?

      if Object.keys(this).length > 0
        console.debug? "setting value to this object with: #{Object.keys this}"
        if value instanceof Object
          @[k] = v for own k, v of value when k of this
      else
        console.log "defining _ for leaf Element to store value"
        Object.defineProperty this, '_', value: value

      #yang.validate this

  transform: (obj={}, opts={}) ->
    unless obj instanceof Object
      throw @error "you must supply 'object' as input to transform"
    return new Element this, obj unless obj instanceof Element

    element = @origin.resolve 'element'
    if element?
      [ ..., key ] = @key
      key = element.key if element.key? # allow override
      console.log "binding '#{key}' with Element instance"

      instance = Element.bind null, @expressions()
      instance[k] = v for own k, v of element if element instanceof Object
      instance._ = obj[key] ? (@origin.resolve 'default')?.arg
      instance.configurable = (@origin.resolve 'config')?.arg isnt false
      if instance.writable? or instance.value?
        instance.value = instance.value.bind this if instance.value instanceof Function
      else
        instance.set = (value) -> instance._ = switch
          when element.set instanceof Function then element.set.call (new instance), value
          else new instance value

        instance.get = -> switch
          when element.invocable is true
            ((args...) => new promise (resolve, reject) =>
              func = switch
                when element.get instanceof Function then element.get.call instance._
                else instance._?._ ? instance._
              func.apply this, [].concat args, resolve, reject
            ).bind obj
          when element.get instanceof Function then element.get.call instance._
          else instance._?._ ? instance._
      Object.defineProperty obj, key, instance
    else
      key = @key[0]
      console.log "setting '#{key}' with metadata"
      obj.__meta__[key] = @arg

    @once 'change', arguments.callee.bind this, obj
    return obj

  validate: (obj) ->
    obj = new Element this, obj unless obj instanceof Element
    element = @origin.resolve 'element'
    valid = (element.validate?.call obj, obj.__value__)
    valid ?= true
    unless valid
      throw @error "unable to validate object"

module.exports = Yang
