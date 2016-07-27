fs     = require 'fs'
path   = require 'path'
parser = require 'yang-parser'

Element = require './element'
Yang    = require './yang'


(new Compiler)
.include (fs.readFileSync path.resolve __dirname, '../yang-specification.yang')
.resolve {
  action: require './extension/action'

}



class Compiler extends Element

  constructor: (name, spec=[]) ->
    super 'compiler', name,
      scope:
        extension: '0..n'
        typedef:   '0..n'
        module:    '0..n'
    @extends spec...
  
  # parses YANG schema text input into Yang Expression
  #
  # accepts: YANG schema text
  # returns: Yang Expression
  parse: (schema, spec=[]) ->
    try
      schema = (parser.parse schema) if typeof schema is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = schema.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "invalid YANG syntax detected", offender

    unless typeof schema is 'object'
      throw @error "must pass in proper YANG schema"

    kind = switch
      when !!schema.prf then "#{schema.prf}:#{schema.kw}"
      else schema.kw
    tag = schema.arg if !!schema.arg

    ext = (@lookup 'extension', kind)
    ext.eval schema, this

    new Yang kind, tag, 
    .extends schema.substmts.map (x) => @parse x

  # composes arbitrary JS object into Yang Expression
  #
  # accepts: JS object
  # returns: Yang Expression
  compose: (data, opts={}) ->
    # explict compose
    if opts.kind?
      ext = @lookup 'extension', opts.kind
      unless ext instanceof Expression
        throw new Error "unable to find requested '#{opts.kind}' extension"
      return ext.compose data, opts

    # implicit compose (dynamic discovery)
    for ext in @extension when ext.compose instanceof Function
      console.debug? "checking data if #{ext.tag}"
      try return ext.compose data, opts

  resolve: (from..., name) ->
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

  # imports a new YANG module into the Compiler by filename
  import: (name, opts={}) ->
    opts.basedir ?= ''
    opts.resolve ?= true
    extname  = path.extname name
    filename = path.resolve opts.basedir, name
    basedir  = path.dirname filename

    try model = switch extname
      when '.yang' then (@parse (fs.readFileSync filename, 'utf-8')).resolve opts
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
      @update (@import dependency)

      # try the original request again
      model = @import arguments...

    return @update model

module.exports = Compiler
