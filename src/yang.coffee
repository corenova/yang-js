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
  constructor: (schema, parent) ->
    try
      schema = (parser.parse schema) if typeof schema is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = schema.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "invalid YANG syntax detected", offender

    unless schema instanceof Object
      throw @error "must pass in proper YANG schema"

    if schema instanceof Expression
      parent ?= schema.parent
      schema =
        kw:  schema.kind
        arg: schema.tag
        substmts: schema.expressions

    keyword = ([ schema.prf, schema.kw ].filter (e) -> e? and !!e).join ':'
    argument = schema.arg if !!schema.arg

    console.debug? "creating #{keyword} Yang Expression..."

    ext = parent?.lookup 'extension', keyword
    unless (ext instanceof Expression)
      throw @error "encountered unknown extension '#{keyword}'", schema
      
    if argument? and not ext.argument?
      throw @error "cannot contain argument for extension '#{keyword}'", schema
    if ext.argument? and not argument?
      throw @error "must contain argument '#{ext.argument}' for extension '#{keyword}'", schema
      
    origin = if ext instanceof Yang then ext.origin else ext
    super keyword, argument,
      parent:    parent
      scope:     origin.scope ? {}
      resolve:   origin.resolve
      predicate: origin.predicate
      construct: origin.construct
      represent: ext.argument?.tag ? ext.argument

    @extends schema.substmts...
    @resolve()
    
    # perform final scoped constraint validation
    for kind, constraint of @scope when constraint in [ '1', '1..n' ]
      unless @hasOwnProperty kind
        throw @error "constraint violation for required '#{kind}' = #{constraint}"

    Object.defineProperty this, '_created', value: true
    if @parent instanceof Yang and @parent._created isnt true
      @parent.once 'created', => @emit 'created', this
    else @emit 'created', this

  # makes a deep clone of current expression
  # clone: (parent=@parent) -> new Yang this
  
  #   schema = 
  #     kw:  @kind
  #     arg: @tag
  #   new Yang schema, parent
  #   .extends (@expressions.map (x) -> x.clone())...
      
  # override private _extend prototype to always convert to Yang
  _extend: (expr) -> super switch
    when expr instanceof Yang then expr
    else new Yang expr, this

  propertize: (key, value, opts={}) ->
    unless opts instanceof Object
      throw @error "unable to propertize with invalid opts"
      
    opts.expr ?= this
    return new Element key, value, opts
    
  update: (obj, key, value, opts={}) ->
    return unless obj instanceof Object and key?

    property = @propertize key, value, opts
    property.parent = obj
          
    # update containing object with this property for reference
    unless obj.hasOwnProperty '__'
      Object.defineProperty obj, '__', writable: true, value: {}
    obj.__[key] = property

    console.debug? "attach property '#{key}' and return updated obj"
    console.debug? property
    Object.defineProperty obj, key, property

  # Yang Expression can support 'tag' with prefix to another module
  # (or itself).
  lookup: (kind, tag) ->
    return super unless kind? and tag?
    [ prefix..., arg ] = tag.split ':'
    return super unless prefix.length

    prefix = prefix[0]
    # check if current module's prefix
    ctx = @lookup 'prefix'
    return ctx.lookup kind, arg if ctx?.tag is prefix

    # check if submodule's parent prefix
    ctx = @lookup 'belongs-to'
    # console.log "trying to find #{prefix}:#{arg}"
    # console.log 'belongs-to?'
    # console.log ctx
    return ctx.module.lookup kind, arg if ctx?.prefix.tag is prefix

    # check if one of current module's imports
    imports = (@lookup 'import') ? []
    for m in imports when m.prefix?.tag is prefix
      return m.module.lookup kind, arg

  # converts back to YANG schema string
  toString: (opts={}) ->
    opts.space ?= 2 # default 2 spaces
    s = @kind
    if @represent?
      s += ' ' + switch @represent
        when 'value' then "'#{@tag}'"
        when 'text' 
          "\n" + (indent '"'+@tag+'"', ' ', opts.space)
        else @tag
    sub = (@expressions.map (x) -> x.toString opts).join "\n"
    if !!sub
      s += " {\n" + (indent sub, ' ', opts.space) + "\n}"
    else
      s += ';'
    return s

module.exports = Yang
