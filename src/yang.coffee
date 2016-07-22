#
# Yang - bold outward facing expression and interactive manifestation
#
# represents a YANG schema expression (with nested children)

# external dependencies
parser = require 'yang-parser'
indent = require 'indent-string'

Expression = require './expression'

class Yang extends Expression
  
  constructor: (schema, parent) ->
    try
      schema = (parser.parse schema) if typeof schema is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = schema.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "invalid YANG syntax detected", offender

    unless typeof schema is 'object'
      throw @error "must pass in proper YANG schema"

    keyword  = ([ schema.prf, schema.kw ].filter (e) -> e? and !!e).join ':'
    argument = schema.arg if !!schema.arg

    source = @lookup.call parent, 'extension', keyword
    unless source instanceof Expression
      throw @error "encountered unknown extension '#{keyword}'", schema

    @debug? "constructing #{keyword} Yang Expression..."
    super keyword, argument, parent

    source.eval this

    @extends schema.substmts...

    # perform final scoped constraint validation
    for kind, constraint of @scope when constraint in [ '1', '1..n' ]
      unless @hasOwnProperty kind
        throw @error "constraint violation for required '#{kind}' = #{constraint}"

    # properties specific to Yang Expression
    Object.defineProperties this,
      root: get: (-> if @parent instanceof Yang then @parent.root else this ).bind this

  eval: (data) -> switch @kind
    when 'extension'
      if @source?
        @source.argument = @argument
        @source.eval data
    else super
      
  bind: (data) ->
    return unless data instanceof Object
    if data instanceof Function
      @bindings.push data
      return this
    (@locate key)?.bind binding for key, binding of data
    return this

  clone: -> new Yang this

  # primary mechanism for linking external sub-expressions imported from another 'module'
  implements: (exprs...) ->
    exprs = ([].concat exprs...).filter (x) -> x? and !!x
    return this unless exprs.length > 0
    exprs.forEach (expr) =>
      expr.external = true
      @merge expr
    @emit 'changed', exprs
    return this

  # override 'merge' prototype to always convert to Yang Expression
  merge: (expr) -> super switch
    when expr instanceof Yang then expr
    else new Yang expr, this

  locate: (ypath) ->
    # TODO: figure out how to eliminate duplicate code-block section
    # shared with Expression
    return unless typeof ypath is 'string' and !!ypath
    ypath = ypath.replace /\s/g, ''
    if (/^\//.test ypath) and not @root
      return @parent.locate ypath
    [ key, rest... ] = ypath.split('/').filter (e) -> !!e
    return this unless key?

    if key is '..'
      return unless not @root
      return @parent.locate rest.join('/')
      
    match = key.match /^([\._-\w]+):([\._-\w]+)$/
    return super unless match?

    [ prefix, target ] = [ match[1], match[2] ]
    @debug? "looking for '#{prefix}:#{target}'"

    rest = rest.map (x) -> x.replace "#{prefix}:", ''
    skey = [target].concat(rest).join '/'
    
    if @lookup 'prefix', prefix
      @debug? "(local) locate '#{skey}'"
      return super skey

    for m in @import ? [] when m.prefix.tag is prefix
      @debug? "(external) locate #{skey}"
      return m.module.locate skey

    return undefined
      
  # Yang Expression can support 'tag' with prefix to another module
  # (or itself).
  match: (kind, tag) ->
    return super unless kind? and tag? and typeof tag is 'string'
    [ prefix..., arg ] = tag.split ':'
    return super unless prefix.length

    prefix = prefix[0]
    # check if current module's prefix
    ctx = @lookup 'prefix'
    return ctx.match kind, arg if ctx?.tag is prefix

    # check if submodule's parent prefix
    ctx = @lookup 'belongs-to'
    return ctx.module.match kind, arg if ctx?.prefix.tag is prefix

    # check if one of current module's imports
    imports = (@lookup 'import') ? []
    for m in imports when m.prefix.tag is prefix
      return m.module.match kind, arg

  error: (msg, context) ->
    node = this
    epath = ((node.tag ? node.kind) while (node = node.parent) and node instanceof Yang)
    epath = epath.reverse().join '/'
    epath += "[#{@kind}/#{@tag}]"
    super "#{epath} #{msg}", context

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
    sub =
      @expressions
        .filter (x) => x.parent is this
        .map (x) -> x.toString opts
        .join "\n"
    if !!sub
      s += " {\n" + (indent sub, ' ', opts.space) + "\n}"
    else
      s += ';'
    return s

module.exports = Yang
