#
# Yang - evaluable Element (using Extension)
#
# represents a YANG schema expression (with nested children)
# 
# This module provides support for basic set of YANG schema modeling
# language by using the built-in *extension* syntax to define
# additional schema language constructs.

console.debug ?= console.log if process.env.yang_debug?

# external dependencies
fs     = require 'fs'
path   = require 'path'
parser = require 'yang-parser'
indent = require 'indent-string'

# local dependencies
Expression = require './expression'

class Yang extends Expression

  # performs recursive parsing of passed in statement and
  # sub-statements.
  #
  # Provides semantic and contextual validations on the provided
  # schema and returns the final JS object tree structure.
  #
  # Accepts: string or JS Object
  # Returns: new Yang
  @parse: (schema) ->
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
    new this kind, tag
    .extends schema.substmts...

  @compose: (data, opts={}) ->
    # explict compose
    if opts.kind?
      ext = source.lookup 'extension', opts.kind
      unless ext instanceof Expression
        throw new Error "unable to find requested '#{opts.kind}' extension"
      return ext.compose data, opts

    # implicit compose (dynamic discovery)
    for ext in source.extension when ext.compose instanceof Function
      console.debug? "checking data if #{ext.tag}"
      try return new Yang (ext.compose data, key: name), source

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
    opts.basedir ?= ''
    opts.resolve ?= true
    extname  = path.extname name
    filename = path.resolve opts.basedir, name
    basedir  = path.dirname filename

    try model = switch extname
      when '.yang' then @parse (fs.readFileSync filename, 'utf-8')
      when ''      then require (@resolve name)
      else require filename
    catch e
      console.debug? e
      throw e unless opts.resolve and e.name is 'ExpressionError' and e.context.kind is 'import'

      # try to find the dependency module for import
      dependency = @resolve basedir, e.context.tag
      unless dependency?
        e.message = "unable to auto-resolve '#{e.context.tag}' dependency module"
        throw e

      # update Registry with the dependency module
      Registry.update (@require dependency)

      # try the original request again
      model = @require arguments...

    return Registry.update model

  constructor: (kind, tag, extension) ->
    unless @constructor is Yang
      return (-> @eval arguments...).bind (Yang.parse arguments...)

    extension ?= (@lookup 'extension', kind)
    unless extension instanceof Expression
      throw @error "encountered unknown extension '#{kind}'"
    if tag? and not extension.argument?
      throw @error "cannot contain argument for extension '#{kind}'"
    if extension.argument? and not tag?
      throw @error "must contain argument '#{extension.argument}' for extension '#{kind}'"
    
    super kind, tag, extension
    
    Object.defineProperties this,
      datakey: get: (-> switch
        when @parent?.kind is 'module' then "#{@parent.tag}:#{@tag}"
        else @tag
      ).bind this

  merge: (data) -> super switch
    when data instanceof Expression then data
    else Yang.parse data

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

