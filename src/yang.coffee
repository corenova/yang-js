#
# Yang - bold outward facing expression and interactive manifestation
#
# represents a YANG schema expression (with nested children)

# external dependencies
parser  = require 'yang-parser'
indent  = require 'indent-string'

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

    console.debug? "creating #{keyword} Yang Expression..."

    ext = parent?.lookup 'extension', keyword
    unless (ext instanceof Expression)
      throw @error "encountered unknown extension '#{keyword}'", schema
      
    if argument? and not ext.argument?
      throw @error "cannot contain argument for extension '#{keyword}'", schema
    if ext.argument? and not argument?
      throw @error "must contain argument '#{ext.argument}' for extension '#{keyword}'", schema
      
    origin = if ext instanceof Yang then ext.origin else ext
    super (argument ? ''),
      kind:      keyword
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

    @emit 'created', this

  # extends current Yang expression with additional schema definitions
  #
  # accepts: one or more YANG text schema(s) or instances of Yang
  # returns: newly extended Yang Expression
  extends: (exprs...) ->
    return unless exprs.length > 0
    exprs.forEach (expr) =>
      expr = (new Yang expr, this) unless expr instanceof Expression
      @_extend expr.kind, expr
    @emit 'extended', this
    return this

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
