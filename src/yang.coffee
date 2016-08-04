#
# Yang - evaluable expression using built-in extensions and typedefs
#
# represents a YANG schema expression (with nested children)
# 
# This module provides support for basic set of YANG schema modeling
# language by using the built-in *extension* syntax to define
# additional schema language constructs.

# external dependencies
fs     = require 'fs'
path   = require 'path'
parser = require 'yang-parser'
indent = require 'indent-string'

# local dependencies
Expression = require './expression'

class Yang extends Expression

  @scope:
    extension: '0..n'
    typedef:   '0..n'
    module:    '0..n'

  # performs recursive parsing of passed in statement and
  # sub-statements.
  #
  # Provides semantic and contextual validations on the provided
  # schema and returns the final JS object tree structure.
  #
  # Accepts: string or JS Object
  # Returns: new Yang
  @parse: (schema, resolve=true) ->
    try
      schema = parser.parse schema if typeof schema is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = schema.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "invalid YANG syntax detected", offender

    unless schema instanceof Object
      throw @error "must pass in valid YANG schema", schema
      
    kind = switch
      when !!schema.prf then "#{schema.prf}:#{schema.kw}"
      else schema.kw
    tag = schema.arg if !!schema.arg
    model = (new this kind, tag).extends schema.substmts.map (x) => @parse x, false
    # perform final scoped constraint validation
    for kind, constraint of model.scope when constraint in [ '1', '1..n' ]
      unless model.hasOwnProperty kind
        throw model.error "constraint violation for required '#{kind}' = #{constraint}"
    model.resolve resolve unless resolve is false
    return model

  @compose: (data, opts={}) ->
    # explict compose
    if opts.kind?
      ext = Yang::lookup.call this, 'extension', opts.kind
      unless ext instanceof Expression
        throw new Error "unable to find requested '#{opts.kind}' extension"
      return ext.compose? data, opts

    # implicit compose (dynamic discovery)
    for ext in @extension when ext.compose instanceof Function
      console.debug? "checking data if #{ext.tag}"
      res = ext.compose data, opts
      return res if res instanceof Yang

  @resolve: (from..., name) ->
    return null unless typeof name is 'string'
    dir = from = switch
      when from.length then from[0]
      else path.resolve()
    while not found? and dir not in [ '/', '.' ]
      console.debug? "resolving #{name} in #{dir}/package.json"
      try
        found = require("#{dir}/package.json").models[name]
        dir   = path.dirname require.resolve("#{dir}/package.json")
      dir = path.dirname dir unless found?
    file = switch
      when found? and /^[\.\/]/.test found then path.resolve dir, found
      when found? then @resolve found, name
    file ?= path.resolve from, "#{name}.yang"
    console.debug? "checking if #{file} exists"
    return if fs.existsSync file then file else null

  @require: (name, opts={}) ->
    return unless name?
    opts.basedir ?= ''
    opts.resolve ?= true
    extname  = path.extname name
    filename = path.resolve opts.basedir, name
    basedir  = path.dirname filename
    
    return @require (@resolve name) unless !!extname
    return require filename unless extname is '.yang'
    
    try return @use (@parse (fs.readFileSync filename, 'utf-8'))
    catch e
      console.debug? e
      throw e unless opts.resolve and e.name is 'ExpressionError' and e.context.kind is 'import'

      # try to find the dependency module for import
      dependency = @require (@resolve basedir, e.context.tag)
      unless dependency?
        e.message = "unable to auto-resolve '#{e.context.tag}' dependency module"
        throw e

      # retry the original request
      console.debug? "retrying require(#{name})"
      return @require arguments...

  constructor: (kind, tag, extension) ->
    unless @constructor is Yang
      return (-> @eval arguments...).bind (Yang.parse arguments[0], true)

    extension ?= (@lookup 'extension', kind)
    unless extension instanceof Expression
      # see if custom extension
      @once 'resolve', =>
        extension = (@lookup 'extension', kind)
        unless extension instanceof Yang
          throw @error "encountered unknown extension '#{kind}'"
        { @source, @argument } = extension
        
    super kind, tag, extension
    
    Object.defineProperties this,
      datakey: get: (-> switch
        when @parent?.kind is 'module' then "#{@parent.tag}:#{@tag}"
        else @tag
      ).bind this

  locate: (ypath) ->
    # TODO: figure out how to eliminate duplicate code-block section
    # shared with Expression
    return unless typeof ypath is 'string' and !!ypath
    ypath = ypath.replace /\s/g, ''
    if (/^\//.test ypath) and this isnt @root
      return @root.locate ypath
    [ key, rest... ] = ypath.split('/').filter (e) -> !!e
    return this unless key?

    if key is '..'
      return @parent?.locate rest.join('/')
      
    match = key.match /^([\._-\w]+):([\._-\w]+)$/
    return super unless match?

    [ prefix, target ] = [ match[1], match[2] ]
    @debug? "looking for '#{prefix}:#{target}'"

    rest = rest.map (x) -> x.replace "#{prefix}:", ''
    skey = [target].concat(rest).join '/'

    if (@tag is prefix) or (@lookup 'prefix', prefix)
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
    if @root?.prefix?.tag is prefix
      return @root.match kind, arg 

    # check if submodule's parent prefix
    ctx = @lookup 'belongs-to'
    return ctx.module.match kind, arg if ctx?.prefix.tag is prefix

    # check if one of current module's imports
    imports = @root?.import ? []
    for m in imports when m.prefix.tag is prefix
      return m.module.match kind, arg

  error: (msg, context) -> super "#{@trail}[#{@tag}] #{msg}", context

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
