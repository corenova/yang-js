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

  ##
  # The below Element class is used during 'create'
  # 
  # By default, every new Element created using the provided YANG
  # Expression will have implicit event listener and will
  # auto-magically update itself whenever the underlying YANG schema
  # changes.
  ##
  class Element
    constructor: (yang, parent) ->
      tag = switch
        when not yang.argtype? or yang.argtype['yin-element']? then yang.kw
        else yang.arg
          
      console.debug? "making new Element for '#{tag}'"
      
      Object.defineProperties this,
        tag: value: tag
        configurable: writable: true, value: true
        enumerable:   writable: true, value: false
        state: writable: true
        get: writable: true, value: => switch
          when @state instanceof Function
            (args...) => new promise (resolve, reject) =>
              @state.apply parent, [].concat args, resolve, reject
          else @state
        set: writable: true, value: (val) =>
          console.debug? "setting #{tag} with:"
          console.debug? val
          yang.emit 'create', val, this
          if parent instanceof Element
            parent.extend this
          else
            Object.defineProperty parent, @tag, this
            
      yang.expressions().forEach (x) => @extend x if (x.listeners 'create').length > 0

      # listen for Yang schema changes and absorb them
      yang.on 'extend', (changes...) => changes.forEach (x) => @extend x
        
    extend: (data) ->
      element = switch
        when data instanceof Element then data
        else new Element data, this
      @state ?= {}
      Object.defineProperty @state, element.tag, element
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
  create: (data={}) ->
    return unless (@listeners 'create').length > 0
    obj = {}
    element = new Element this, obj
    element.set data
    Object.defineProperty obj, element.tag, element
    return obj

  validate: (obj) ->
    obj = new Element this, obj unless obj instanceof Element
    element = @origin.resolve 'element'
    valid = (element.validate?.call obj, obj.__value__)
    valid ?= true
    unless valid
      throw @error "unable to validate object"

module.exports = Yang
