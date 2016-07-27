#
# Yang - evaluable Element (using Extension)
#
# represents a YANG schema expression (with nested children)

# external dependencies
indent = require 'indent-string'

Element   = require './element'
Extension = require './extension'

class Yang extends Element
  
  constructor: (kind, tag, extension) ->
    unless extension instanceof Extension
      throw @error "unable to create #{kind} Yang Element without extension"

    if tag? and not extension.argument?
      throw @error "cannot contain argument for #{kind}"
    if extension.argument? and not tag?
      throw @error "must contain argument '#{extension.argument}' for #{kind}"
    
    super kind, tag, extension
        
    Object.defineProperties this,
      source:   value: extension
      binding:  writable: true
      resolved: value: false, writable: true

  clone: -> (new Yang @kind, @tag, @source).extends @elements.map (x) -> x.clone()

  resolve: ->
    return if @resolved is true
    
    @source.resolve.apply this, arguments
    @elements.forEach (x) -> x.resolve arguments...
    
    # perform final scoped constraint validation
    for kind, constraint of @scope when constraint in [ '1', '1..n' ]
      unless @hasOwnProperty kind
        throw @error "constraint violation for required '#{kind}' = #{constraint}"
    @resolved = true
    return this

  bind: (data) ->
    return unless data instanceof Object
    if data instanceof Function
      @binding = data
      return this

    @resolve() unless @resolved
    for key, binding of data      
      try (@locate key).bind binding
      catch e
        throw e if e.name is 'ElementError'
        throw @error "failed to bind to '#{key}", e
    return this

  eval: (data, opts={}) ->
    @resolve() unless @resolved
    
    opts.adaptive ?= true
    data = @source.construct.call this, data
    unless @source.predicate.call this, data
      throw @error "predicate validation error during eval", data
    if opts.adaptive
      @once 'changed', arguments.callee.bind(this, data)
    @emit 'eval', data
    return data

  # primary mechanism for linking external sub-elements imported from another 'module'
  implements: (exprs...) ->
    exprs = ([].concat exprs...).filter (x) -> x? and !!x
    return this unless exprs.length > 0
    exprs.forEach (expr) =>
      expr.external = true
      @merge expr
    @emit 'changed', exprs
    return this

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
    if @source.argument?
      s += ' ' + switch @source.argument
        when 'value' then "'#{@tag}'"
        when 'text' 
          "\n" + (indent '"'+@tag+'"', ' ', opts.space)
        else @tag
    sub =
      @elements
        .filter (x) => x.parent is this
        .map (x) -> x.toString opts
        .join "\n"
    if !!sub
      s += " {\n" + (indent sub, ' ', opts.space) + "\n}"
    else
      s += ';'
    return s

module.exports = Yang
