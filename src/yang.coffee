#
# Yang - bold outward facing expression and interactive manifestation
#
# represents a YANG schema expression (with nested children)

# external dependencies
parser  = require 'yang-parser'
indent  = require 'indent-string'

# local dependencies
Expression = require './expression'
Element    = require './element'

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
  constructor: (schema, data={}) ->
    # 1. initialize this Expression
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

    Object.defineProperties this,
      arg:     writable: true, enumerable: true, value: argument
      argtype: writable: true

    super keyword, data

    # 2. handle sub-expressions for this Expression
    origin = @resolve 'extension', keyword
    unless (origin instanceof Expression)
      throw @error "encountered unknown extension '#{keyword}'", schema

    if argument? and not origin.argument?
      throw @error "cannot contain argument for extension '#{keyword}'", schema

    @scope = (origin.resolve 'scope') ? {}
    @argtype = origin.argument.arg ? origin.argument

    @extends schema.substmts...

    # 3. call custom 'construct' for this Expression
    try
      (origin.resolve 'construct')?.call this
    catch e
      console.error e
      throw @error "failed to construct Yang Expression for '#{keyword} #{argument}'", this

    # 4. perform final scoped constraint validation
    for kw, constraint of @scope when constraint in [ '1', '1..n' ]
      unless @hasOwnProperty kw
        throw @error "constraint violation for required '#{kw}' = #{constraint}"

  # extends current Yang expression with additional schema definitions
  #
  # accepts: one or more YANG text schema, JS object, or an instance of Yang
  # returns: newly extended Yang Expression
  extend: (schema, suppress=false) ->
    schema = new Yang schema, parent: this unless schema instanceof Expression
    console.debug? "[Yang:extend:#{@kw}] #{schema.kw} { #{Object.keys schema} }"
    super schema
    # trigger listeners for this Yang Expression to initiate transform(s)
    @emit 'extend', schema unless suppress is true
    return schema

  # convenience for extending multiple schema expressions into current Yang Expression
  # returns: this Yang instance with updated property definition(s)
  extends: (schema...) ->
    changes = schema.filter( (x) -> x? and !!x ).map (x) => @extend x, true
    @emit 'extend', changes...
    return this

  # recursively look for matching Expressions using kw and arg
  resolve: (kw, arg) ->
    return super unless arg?

    [ prefix..., arg ] = arg.split ':'
    if prefix.length and @hasOwnProperty prefix[0]
      return @[prefix[0]].resolve? kw, arg

    if (@hasOwnProperty kw) and @[kw] instanceof Array
      for expr in @[kw] when expr? and expr.arg is arg
        return expr

    return @parent?.resolve? arguments...

  transform: (target={}) ->
    @expressions().forEach (x) ->
      elem = x.createElement parent: target
      return unless elem?
      
      elem.set target[elem.kw]
      Object.defineProperty target, elem.kw, elem
      elem.on 'updated', ->
        Object.defineProperty target, elem.kw, elem
        
    @emit 'transform', target
    return target

  # createElement: (opts={}) ->
  #   return unless (@listeners 'create').length > 0
  #   tag = switch
  #     when not @argtype? or @argtype['yin-element']? then @kw
  #     else @arg
  #   element = new Element tag, opts
  #   @transform element
  #   @emit 'create', element
  #   return element

  createElement: (opts={}) ->
    return unless (@listeners 'create').length > 0
    tag = switch
      when not @argtype? or @argtype['yin-element']? then @kw
      else @arg

    element = new Element tag, opts
    element.scope = @expressions().reduce ((a,b) ->
      elem = b.createElement parent: element
      return a unless elem?
      a[elem.kw] = elem
      elem.on 'updated', ->
        if elem.kw of (element.state ? {})
          Object.defineProperty element.state, elem.kw, elem
      return a
    ), element.scope ? {}
    @emit 'create', element
    return element

  ###
  # The `create` routine is the primary method which enables the
  # Yang Expression to become manifest.
  #
  # This routine accepts an arbitrary JS object and transforms it
  # according to the current Yang Expression.  It will also re-apply
  # pre-existing values back to the newly transformed object.
  #
  # The returned object essentially becomes a living manisfestation of
  # the Yang Expression.
  ###
  create: (data) ->
    obj = {}
    element = @createElement parent: obj
    Object.defineProperty obj, element.kw, element
    Object.defineProperty obj, '__element__', value: element
    element.on 'updated', ->
      Object.defineProperty obj, element.kw, element
    element.set data if data?
    return obj

  validate: (data) ->
    try @create data; return true
    catch e then return false

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

    exprs = @expressions().map (x) -> x.toString opts
    if exprs.length
      s += " {\n" + (indent (exprs.join "\n"), ' ', opts.space) + "\n}"
    else
      s += ';'
    return s

module.exports = Yang
