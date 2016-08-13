#
# Yang - evaluable expression using built-in extensions and typedefs
#
# represents a YANG schema expression (with nested children)
# 
# This module provides support for basic set of YANG schema modeling
# language by using the built-in *extension* syntax to define
# additional schema language constructs.

# external dependencies
fs      = require 'fs'
path    = require 'path'
parser  = require 'yang-parser'
indent  = require 'indent-string'
Emitter = (require 'events').EventEmitter

# local dependencies
Expression = require './expression'
XPath      = require './xpath'

class Model extends Emitter

  constructor: (data, schema) ->
    return unless data? and data.__props__ instanceof Object
    Object.defineProperties this,
      '_id': value: schema.tag
      '__':  value: { name: schema.tag, schema: schema }
      '__props__': value: {}
      '_events':   writable: true
    for k, prop of data.__props__ when (@access k)?
      prop.parent = this
      @__props__[k] = prop
      Object.defineProperty this, k, prop
    Object.preventExtensions this

  # helper routine to parse REST URI and discover XPATH and Yang
  # TODO: make URI parsing into XPATH configurable
  access: (uri='') ->
    keys = uri.split('/').filter (x) -> x? and !!x
    expr = @__.schema
    unless keys.length and expr?
      return {
        model:  this
        schema: expr
        path:   XPath.parse '.'
        match:  this
      }
    key = keys.shift()
    expr = switch expr.kind
      when 'module' then switch
        when expr.tag is key then expr
        else expr.locate key
      else switch
        when expr.tag is key then expr
        else undefined

    str = "/#{key}"
    while (key = keys.shift()) and expr?
      if expr.kind is 'list' and not (expr.locate key)?
        str += "[key() = '#{key}']"
        key = keys.shift()
        li = true
        break unless key?
      expr = expr.locate key
      str += "/#{expr.datakey}" if expr?
    return if keys.length or not expr?

    try
      xpath = XPath.parse str
      temp = xpath
      key = temp.tag while (temp = temp.xpath)

    match = xpath.apply this
    match = switch
      when not match?.length then undefined
      when /list$/.test(expr.kind) and not li then match
      else match[0]

    return {
      model:  this
      schema: expr
      path:   xpath
      match:  match
      key:    key
    }

class Yang extends Expression

  @scope:
    extension: '0..n'
    typedef:   '0..n'
    module:    '0..n'
    submodule: '0..n'

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
      e.offset = 50 unless e.offset > 50
      offender = schema.slice e.offset-50, e.offset+50
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

    unless !!extname
      return (Yang::match.call this, 'module', name) ? @require (@resolve name), opts
      
    return require filename unless extname is '.yang'
    
    try return @use (@parse (fs.readFileSync filename, 'utf-8'), opts.resolve)
    catch e
      unless opts.resolve and e.name is 'ExpressionError' and e.context.kind in [ 'include', 'import' ]
        console.error "unable to require YANG module from '#{filename}'"
        console.error e
        throw e 
      opts.resolve = false if e.context.kind is 'include'

      # try to find the dependency module for import
      dependency = @require (@resolve basedir, e.context.tag), opts
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
      @once 'resolve:before', =>
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

  # eval on Yang produces a Model
  eval: ->
    data = super
    new Model data, this if data?
    
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

exports = module.exports = Yang
exports.Model = Model
