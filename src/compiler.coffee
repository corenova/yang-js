### yang-compiler
#
# The **yang-compiler** class provides support for basic set of
# YANG schema modeling language by using the built-in *extension* syntax
# to define additional schema language constructs.

# The compiler only supports bare minium set of YANG statements and
# should be used only to generate a new compiler such as [yangforge](./yangforge.coffee)
# which implements the version 1.0 of the YANG language specifications.
#
###

synth  = require 'data-synth'
yaml   = require 'js-yaml'
coffee = require 'coffee-script'
parser = require 'yang-parser'
fs     = require 'fs'
path   = require 'path'

YANG_SPEC_SCHEMA = yaml.Schema.create [

  new yaml.Type '!require',
    kind: 'scalar'
    resolve:   (data) -> typeof data is 'string'
    construct: (data) ->
      console.log "processing !require using: #{data}"
      require data
      #require (path.resolve pkgdir, data)

  new yaml.Type '!coffee',
    kind: 'scalar'
    resolve:   (data) -> typeof data is 'string'
    construct: (data) -> coffee.eval? data

  new yaml.Type '!coffee/function',
    kind: 'scalar'
    resolve:   (data) -> typeof data is 'string'
    construct: (data) -> coffee.eval? data
    predicate: (obj) -> obj instanceof Function
    represent: (obj) -> obj.toString()

  new yaml.Type '!yang',
    kind: 'scalar'
    resolve:   (data) -> typeof data is 'string'
    construct: (data) =>
      console.log "processing !yang using: #{data}"
      (new Compiler {}).parse data
]

loadSpec = (data) -> yaml.load data, schema: YANG_SPEC_SCHEMA

class Compiler

  #----------------
  # PRIMARY METHOD
  #----------------
  # This routine is the primary recommended interface when using this Compiler
  #
  # accepts: variable arguments of YANG schema string(s) and YANG spec
  # object(s)
  #
  # returns: a new Compiler instance with newly updated @SourceMap
  load: -> new Compiler this, arguments...

  constructor: (@parent, sources...) ->
    unless @parent?
      console.info "initializing YANG Version 1.0 Specification and Schema"
      v1_spec = fs.readFileSync (path.resolve __dirname, '../yang-v1-spec.yaml'), 'utf-8'
      v1_yang = fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yang'), 'utf-8'
      sources.push (loadSpec v1_spec), v1_yang

    # XXX - consider making a copy of @parent.SourceMap here?
    @SourceMap = {}
    for source in sources
      switch typeof source
        when 'object' then synth.copy @SourceMap, source
        when 'string' then @compile source
        else throw @error "invalid argument type passed into load()", source

  define: (type, key, value, global=false) ->
    _define = (to, type, key, value) =>
      [ prefix..., key ] = key.split ':'
      base = switch
        when global is true then to
        when prefix.length > 0
          to[prefix[0]] ?= {}
          to[prefix[0]]
        when @moduleName?
          to[@moduleName] ?= {}
          to[@moduleName]
        else
          to
      synth.copy base, (synth.objectify "#{type}.#{key}", value)

    exists = @resolve type, key, false
    switch
      when not exists?
        console.log "a new definition for #{@moduleName} with #{type} and #{key}"
        _define @SourceMap, arguments...
      when synth.instanceof exists
        exists.merge value
      when synth.instanceof value
        _define @SourceMap, type, key, (value.override exists)
      when exists.constructor is Object
        synth.copy exists, value
    return this

  #
  # resolving a defined symbol type (extension, grouping, etc.) using
  # a specified key
  #
  # The 'key' can be in two forms, "foo:bar" or simply "bar'.
  #
  # Search operation uses following scope(s) in order
  # 1. local scope (within specified/current module)
  # 2. global scope (available to all modules)
  resolve: (type, key, warn=true) ->
    #console.log "resolve #{type}:#{key}"
    source = @SourceMap
    unless key?
      # TODO: we may want to grab other definitions from imported modules here
      return source[@moduleName]?[type] ? source[type] ? @parent?.resolve? type

    [ prefix..., key ] = key.split ':'
    match = switch
      when prefix.length > 0 then source[prefix[0]]?[type]?[key]
      else source[@moduleName]?[type]?[key] ? source[type]?[key]
    match ?= @parent?.resolve? arguments...
    unless match?
      console.log "[resolve] unable to find #{type}:#{key}" if warn
      console.log source
    return match

  locate: (inside, path) ->
    return unless inside? and typeof path is 'string'
    if /^\//.test path
      console.warn "[locate] absolute-schema-nodeid is not yet supported, ignoring #{path}"
      return
    [ target, rest... ] = path.split '/'

    #console.log "locating #{path}"
    if inside.access instanceof Function
      return switch
        when target is '..'
          if (inside.parent.meta 'synth') is 'list'
            @locate inside.parent.parent, rest.join '/'
          else
            @locate inside.parent, rest.join '/'
        when rest.length > 0 then @locate (inside.access target), rest.join '/'
        else inside.access target

    for key, val of inside when val.hasOwnProperty target
      return switch
        when rest.length > 0 then @locate val[target], rest.join '/'
        else val[target]
    console.warn "[locate] unable to find '#{path}' within #{Object.keys inside}"
    return

  error: (msg, context) ->
    res = new Error msg
    res.name = 'CompileError'
    res.context = context
    return res

  normalize = (obj) -> ([ obj.prf, obj.kw ].filter (e) -> e? and !!e).join ':'

  ###
  # The `parse` function performs recursive parsing of passed in statement
  # and sub-statements and usually invoked in the context of the
  # originating `compile` function below.  It expects the `statement` as
  # an Object containing prf, kw, arg, and any substmts as an array.  It
  # currently does NOT perform semantic validations but rather simply
  # ensures syntax correctness and building the JS object tree structure.
  ###
  parse: (input) ->
    try
      input = (parser.parse input) if typeof input is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = input.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "[yang-compiler:parse] invalid YANG syntax detected", offender

    unless input instanceof Object
      throw @error "[yang-compiler:parse] must pass in proper input to parse"

    params =
      (@parse stmt for stmt in input.substmts)
      .filter (e) -> e?
      .reduce ((a, b) -> synth.copy a, b, true), {}
    params = null unless Object.keys(params).length > 0

    synth.objectify "#{normalize input}", switch
      when not params? then input.arg
      when not !!input.arg then params
      else "#{input.arg}": params

  extractKeys = (x) -> if x instanceof Object then (Object.keys x) else [x].filter (e) -> e? and !!e

  ###
  # The `preprocess` function is the intermediary method of the compiler
  # which prepares a parsed output to be ready for the `compile`
  # operation.  It deals with any `include` and `extension` statements
  # found in the parsed output in order to prepare the context for the
  # `compile` operation to proceed smoothly.
  ###
  preprocess: (schema, scope) ->
    schema = (@parse schema) if typeof schema is 'string'
    unless schema instanceof Object
      throw @error "must pass in proper 'schema' to preprocess"

    unless scope?
      @moduleName = (extractKeys (schema.module ? schema.submodule))[0]
      #console.log "[preprocess:#{@moduleName}] start"
      try @preprocess schema, (@resolve 'extension')
      finally delete @moduleName
      return schema

    # Here we go through each of the keys of the schema object and
    # validate the extension keywords and resolve these keywords
    # if constructors are associated with these extension keywords.
    for key, val of schema
      [ prf..., kw ] = key.split ':'
      unless kw of scope
        throw @error "invalid '#{kw}' extension found during preprocess operation", schema

      if key is 'extension'
        extensions = (extractKeys val)
        for name in extensions
          extension = if val instanceof Object then val[name] else {}
          for ext of extension when ext isnt 'argument' # TODO - should qualify better
            delete extension[ext]
          @define 'extension', name, extension
        delete schema.extension
        console.log "[preprocess:#{@moduleName}] found #{extensions.length} new extension(s)"
        continue

      ext = @resolve 'extension', key
      unless (ext instanceof Object)
        throw @error "[preprocess:#{@moduleName}] encountered unresolved extension '#{key}'", schema
      constraint = scope[kw]

      unless ext.argument?
        # TODO - should also validate constraint for input/output
        @preprocess val, ext
        ext.preprocess?.call? this, key, val, schema
      else
        args = (extractKeys val)
        valid = switch constraint
          when '0..1','1' then args.length <= 1
          when '1..n' then args.length > 1
          else true
        unless valid
          throw @error "[preprocess:#{@moduleName}] constraint violation for '#{key}' (#{args.length} != #{constraint})", schema
        for arg in args
          params = if val instanceof Object then val[arg]
          argument = switch
            when typeof arg is 'string' and arg.length > 50
              ((arg.replace /\s\s+/g, ' ').slice 0, 50) + '...'
            else arg
          console.log "[preprocess:#{@moduleName}] #{key} #{argument} " + if params? then "{ #{Object.keys params} }" else ''
          params ?= {}
          @preprocess params, ext
          try
            ext.preprocess?.call? this, arg, params, schema
          catch e
            console.error e
            throw @error "[preprocess:#{@moduleName}] failed to preprocess '#{key} #{arg}'", args

    return schema

  ###
  # The `compile` function is the primary method of the compiler which
  # takes in YANG schema input and produces JS output representing the
  # input schema as meta data hierarchy.

  # It accepts following forms of input
  # * YANG schema text string
  # * function that will return a YANG schema text string

  # The compilation process can compile any partials or complete
  # representation of the schema and recursively compiles the data tree to
  # return synthesized object hierarchy.
  ###
  compile: (schema, scope) ->
    schema = (schema.call this) if schema instanceof Function
    schema = @preprocess schema if typeof schema is 'string'
    unless schema instanceof Object
      throw @error "must pass in proper 'schema' to compile"

    unless scope?
      @moduleName ?= (extractKeys (schema.module ? schema.submodule))[0]
      #console.log "[compile:#{@moduleName}] start"
      try output = @compile schema, true
      finally delete @moduleName
      return output

    output = {}
    for key, val of schema
      continue if key is 'extension'

      ext = @resolve 'extension', key
      unless (ext instanceof Object)
        throw @error "[compile:#{@moduleName}] encountered unknown extension '#{key}'", schema

      # here we short-circuit if there is no 'construct' for this extension
      continue unless ext.construct instanceof Function

      unless ext.argument?
        console.log "[compile:#{@moduleName}] #{key} " + if val instanceof Object then "{ #{Object.keys val} }" else val
        children = @compile val, ext
        output[key] = ext.construct.call this, key, val, children, output, ext
        delete output[key] unless output[key]?
      else
        for arg in (extractKeys val)
          params = if val instanceof Object then val[arg]
          console.log "[compile:#{@moduleName}] #{key} #{arg} " + if params? then "{ #{Object.keys params} }" else ''
          params ?= {}
          children = @compile params, ext
          try
            output[arg] = ext.construct.call this, arg, params, children, output, ext
            delete output[arg] unless output[arg]?
          catch e
            console.error e
            throw @error "[compile:#{@moduleName}] failed to compile '#{key} #{arg}'", schema

    return output

#
# declare exports
#
exports = module.exports = new Compiler
exports.loadSpec = loadSpec
exports.Compiler = Compiler

# below is a convenience wrap for programmatic creation of YANG Module Class
exports.Module = class extends synth.Model
  @schema = -> @extend (exports.compile arguments...)
