#
# Yang - bold outward facing expression and interactive manifestation
#
# represents a YANG schema expression (with nested children)

# external dependencies
parser  = require 'yang-parser'
indent  = require 'indent-string'
promise = require 'promise'

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
  constructor: (parent, schema, obj) ->
    unless parent instanceof Expression
      throw @error "Yang must always be created from a parent Expression";

    try
      schema = (parser.parse schema) if typeof schema is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = schema.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "invalid YANG syntax detected", offender

    unless schema instanceof Object
      throw @error "must pass in proper YANG schema"

    keyword = ([ schema.prf, schema.kw ].filter (e) -> e? and !!e).join ':'
    argument = schema.arg if !!schema.arg

    super parent, keyword, argument

    origin = @resolve 'extension', keyword
    unless (origin instanceof Expression)
      throw @error "encountered unknown extension '#{keyword}'", schema

    if argument? and not origin.argument?
      throw @error "cannot contain argument for extension '#{keyword}'", schema

    @scope = (origin.resolve 'scope') ? {}
    @argtype ?= origin.argument.arg ? origin.argument

    # extend using sub-statement YANG expressions
    @extend schema.substmts...

    try
      (origin.resolve 'construct')?.call this
    catch e
      console.error e
      throw @error "failed to construct Yang Expression for '#{keyword} #{argument}'", this

    # perform overall scoped constraint validation
    for kw, constraint of @scope when constraint in [ '1', '1..n' ]
      unless @hasOwnProperty kw
        throw @error "constraint violation for required '#{kw}' = #{constraint}"

    # perform optional obj transformation
    @transform obj if obj?
      
  # extends current Yang expression with additional schema definitions
  #
  # accepts: one or more YANG text schema, JS object, or an instance of Yang
  # returns: this Yang instance with updated property definition(s)
  extend: (schema..., ignoreError=false) ->
    unless typeof ignoreError is 'boolean'
      schema.push ignoreError
      ignoreError = false
    return this unless schema.length > 0

    console.debug? "[Yang:extend:#{@kw}] processing #{schema.length} sub-statement(s)"
    schema
    .filter  (x) -> x? and !!x
    .forEach (x) =>
      x = new Yang this, x unless x instanceof Yang
      console.debug? "[Yang:extend:#{@kw}] #{x.kw} { #{Object.keys x} }"
      super x

    # trigger listeners for this Yang Expression to initiate transform(s)
    @emit 'changed', this
    return this

  # converts back to YANG schema string
  toString: (opts={}) ->
    opts.space ?= 2 # default 2 spaces
    s = @kw
    if @argtype?
      s += ' ' + switch @argtype
        when 'value' then "'#{@arg}'"
        when 'text' 
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

  ###
  # The `transform` routine is the primary method which enables the
  # Yang Expression to become manifest.
  #
  # This routine accepts an arbitrary JS object and transforms it
  # according to the current Yang Expression.  It will re-apply
  # pre-existing values back to the newly transformed object.
  #
  # The `transform` can be applied at any position of the Yang
  # Expression tree but only the expressions that have corresponding
  # 'transform' definition will produce an interesting result.
  #
  # By default, every new property defined for the transformed object
  # will have implicit event listener to the underlying YANG
  # Expression to which it is bound and will auto-magically update
  # itself whenever the underlying YANG schema changes.
  #
  # The returned transformed object essentially becomes a living
  # manisfestation of the Yang Expression.
  ###
  transform: (obj={}) ->
    unless obj instanceof Object
      throw @error "you must supply 'object' as input to transform"

    element = obj[@key] ? {}
    @expressions().forEach (expr) -> expr.transform element

    Object.defineProperties obj, @expressions().reduce ((a,b) ->
      obj[b.key] # existing value
      a[b.key] = b; a
    ), {}

    Object.defineProperty obj, @key, element
    
    # listen for Yang schema changes and perform re-transformation
    @once 'changed', arguments.callee.bind this, obj
    return obj

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


  validate: (obj) ->
    obj = new Element this, obj unless obj instanceof Element
    element = @origin.resolve 'element'
    valid = (element.validate?.call obj, obj.__value__)
    valid ?= true
    unless valid
      throw @error "unable to validate object"

module.exports = Yang
