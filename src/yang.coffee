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

    # TODO get rid of this...
    Object.defineProperties this,
      arg:     enumerable: true, value: argument
      argtype: value: ext.argument.arg ? ext.argument

    @on 'created', =>
      @extends schema.substmts...
      @resolve.call this
      # 4. perform final scoped constraint validation
      for kw, constraint of @scope when constraint in [ '1', '1..n' ]
        unless @hasOwnProperty kw
          throw @error "constraint violation for required '#{kw}' = #{constraint}"

    origin = switch
      when ext instanceof Yang then ext.origin
      else ext

    return super keyword,
      parent:    parent
      scope:     origin.scope ? {}
      resolve:   origin.resolve
      predicate: origin.predicate
      construct: origin.construct
      represent: origin.represent

  # extends current Yang expression with additional schema definitions
  #
  # accepts: one or more YANG text schema(s) or instances of Yang
  # returns: newly extended Yang Expression
  extends: (exprs...) -> exprs.forEach (expr) => super (new Yang expr, this)

  # recursively look for matching Expressions using kw and arg
  lookup: (kw, arg) ->
    return super unless arg?

    [ prefix..., arg ] = arg.split ':'
    if prefix.length and @hasOwnProperty prefix[0]
      return @[prefix[0]].lookup? kw, arg

    if (@hasOwnProperty kw) and @[kw] instanceof Array
      for expr in @[kw] when expr? and expr.arg is arg
        return expr

    return @parent?.lookup? arguments...

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

    exprs = @expressions.map (x) -> x.toString opts
    if exprs.length
      s += " {\n" + (indent (exprs.join "\n"), ' ', opts.space) + "\n}"
    else
      s += ';'
    return s

module.exports = Yang
