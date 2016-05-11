indent = require 'indent-string'

Origin = require './origin'
Yin    = require './yin'
Yang   = require './yang'
Synth  = require 'data-synth'

# compiles YIN/YANG schemas
class Compiler extends Origin
  constructor: ->
    super

    @set 'synthesizer', Synth
    @set 'serialize', (obj, opts={}) =>
      opts.format ?= 'yang'
      opts.space  ?= 2
      res = switch opts.format
        when 'yaml' then yaml.dump obj, lineWidth: -1
        when 'yang' then @dump obj, opts.space
        else throw @error "unable to serialize to unknown format: #{opts.format}", obj
      res = switch opts.encoding
        when 'base64' then (new Buffer res).toString 'base64'
        else res
      return res

    unless (Compiler::resolve.call this, 'extension')?
      @define 'extension',
        specification:
          argument: 'name'
          scope:
            global:    '0..1'
            extension: '0..n'
            typedef:   '0..n'
            rpc:       '0..n'
            value:     '0..1'
          preprocess: (arg, params, ctx, compiler) ->
            if params.value?
              data = (new Buffer params.value, 'base64').toString 'binary'
              { schema } = compiler.preprocess data, this
              delete params.value
              @copy params, schema
            @origin.define 'specification', arg, params
          represent:  (arg, obj, opts) ->
            serialize = @resolve 'serialize'
            data = (serialize obj, format: 'yaml', encoding: 'base64')
            "specification #{arg} {#{@dump value: data, opts}}"

        module:
          argument: 'name'
    return this

  #### PRIMARY API METHODS ####

  # produces new compiled object instances generated from provided
  # schema(s)
  #
  # accepts: variable arguments of YANG schema file(s)
  # returns: new Yin object containing compiled schema definitions
  load: ->
    input = [].concat arguments...
    unless input.length > 0
      throw @error "no input schema(s) to load"
    (new Yin this).use input

  # converts passed in JS object back into YANG schema (if possible)
  #
  # accepts: JS object
  # returns: YANG schema text
  dump: (obj, space=2, scope) ->
    return '' unless obj? # throw error?

    output = ''
    output += "\n" if space?

    for k, v of obj when v?
      kw = switch
        when v instanceof Function and !!v.yang then v.yang
        else k
      ext = @resolve 'extension', kw
      continue unless ext? and (not scope? or kw of scope)

      dumper  = (ext.represent?.bind this)
      dumper ?= (arg, obj) =>
        arg = "'#{arg}'" if ext.argument is 'value'
        "#{k} #{arg}" + switch
          when obj instanceof Object then " {#{@dump obj, space, ext.scope}}"
          else ';'

      str = switch
        when v instanceof Function then dumper k, v, space
        when not ext.argument?     then dumper '', v, space
        when ext.argument is 'text' or ext.argument.text?
          "#{k}\n" +(indent '"'+v+'";', ' ', space)
        when v instanceof Object
          ((dumper arg, params, space) for arg, params of v)
            .join if space? then "\n" else ' '
        else
          dumper v

      str += "\n" if space?
      output += str

    return indent output, ' ', space

  #### SECONDARY API METHODS ####

  # process schema/spec input(s) and defines results inside current
  # Compiler instance
  #
  # accepts: variable arguments of YANG/YAML schema/specification string(s)
  # returns: current Compiler instance (with updated definitions)
  use: (origins...) ->
    origins.forEach (x) =>
      switch
        when x instanceof Origin then @set x.map
        else @set (@compile x)
    return this

  error: (msg, context=this) ->
    res = super
    res.name = 'CompilerError'
    return res

  normalize   = (obj) -> ([ obj.prf, obj.kw ].filter (e) -> e? and !!e).join ':'
  extractKeys = (x) -> if x instanceof Object then (Object.keys x) else [x].filter (e) -> e? and !!e

  ###
  # The `compile` function is the primary method of the compiler which
  # takes in YANG schema input and produces JS output representing the
  # input schema as meta data hierarchy.

  # It accepts following forms of input
  # * YANG schema text string
  # * YAML schema text string (including specification)

  # The compilation process can compile any partials or complete
  # representation of the schema and recursively compiles the data tree to
  # return synthesized object hierarchy.
  ###
  compile: (schema, map, scope) ->
    { schema, map } = @preprocess schema unless map?
    unless schema instanceof Object
      throw @error "must pass in proper 'schema' to compile"
    unless map instanceof Origin
      throw @error "unable to access Origin map to compile passed in schema"

    scope ?= map.resolve 'extension'

    output = {}
    for key, val of schema
      [ prf..., kw ] = key.split ':'
      unless (key of scope) or (kw of scope)
        throw @error "scope violation - invalid '#{key}' extension found during compile", schema
      constraint = scope[key] ? scope[kw]

      ext = map.resolve 'extension', key
      unless (ext instanceof Object)
        throw @error "encountered unknown extension '#{key}'", schema

      # here we short-circuit if there is no 'construct' for this extension
      continue unless ext.construct instanceof Function

      unless ext.argument?
        console.debug? "[Compiler:compile:#{map.name}] #{key} " + if val instanceof Object then "{ #{Object.keys val} }" else val
        children = Compiler::compile.call this, val, map, ext.scope
        output[key] = ext.construct.call map, key, val, children, output, ext
        if output[key]?
          output[key].yang = key
        else
          delete output[key]
      else
        args = (extractKeys val)
        valid = switch constraint
          when '0..1','1' then args.length <= 1
          when '1..n' then args.length > 1
          else true
        unless valid
          throw @error "constraint violation for '#{key}' (#{args.length} != #{constraint})", schema

        for arg in (extractKeys val)
          params = if val instanceof Object then val[arg]
          console.debug? "[Compiler:compile:#{map.name}] #{key} #{arg} " + if params? then "{ #{Object.keys params} }" else ''
          params ?= {}
          children = Compiler::compile.call this, params, map, ext.scope
          try
            output[arg] = ext.construct.call map, arg, params, children, output, ext
            if output[arg]?
              output[arg].yang = key
            else
              delete output[arg]
          catch e
            console.error e
            throw @error "failed to compile '#{key} #{arg}'", schema

    return output

  ###
  # The `preprocess` function is the intermediary method of the compiler
  # which prepares a parsed output to be ready for the `compile`
  # operation.  It deals with any `include` and `extension` statements
  # found in the parsed output in order to prepare the context for the
  # `compile` operation to proceed smoothly.
  ###
  preprocess: (schema, map) ->
    schema = (@parse schema) if typeof schema is 'string'
    unless schema instanceof Object
      throw @error "must pass in proper 'schema' to preprocess"

    map ?= new Origin this

    # Here we go through each of the keys of the schema object and
    # validate the extension keywords and resolve these keywords
    # if preprocessors are associated with these extension keywords.
    for key, val of schema
      ext = map.resolve 'extension', key
      continue unless (ext instanceof Object)

      unless ext.argument?
        # TODO - should also validate constraint for input/output
        Compiler::preprocess.call this, val, map
        ext.preprocess?.call? map, key, val, schema, this
      else
        args = (extractKeys val)
        if key is 'extension'
          console.debug? "[Compiler:preprocess:#{map.name}] found #{args.length} new extension(s)"

        for arg in args
          if key in [ 'module', 'submodule' ]
            map.name = arg
            # TODO: what if map was supplied as an argument?
            console.debug? "[Compiler:preprocess:#{map.name}] loading specification for '#{map.name}'"
            map.set (Compiler::resolve.call this, 'specification', map.name, warn: false)
            ext = map.resolve 'extension', key

          params = if val instanceof Object then val[arg]
          argument = switch
            when typeof arg is 'string' and arg.length > 50
              ((arg.replace /\s\s+/g, ' ').slice 0, 50) + '...'
            else arg
          console.debug? "[Compiler:preprocess:#{map.name}] #{key} #{argument} " + if params? then "{ #{Object.keys params} }" else ''
          params ?= {}
          unless key is 'extension'
            Compiler::preprocess.call this, params, map
          try
            ext.preprocess?.call? map, arg, params, schema, this
          catch e
            console.error e
            throw @error "failed to preprocess '#{key} #{arg}'", args

    return schema: schema, map: map

  ###
  # The `parse` function performs conversion of YIN schema input
  # format (YAML) and returns the JS object
  ###
  parse: (input) ->
    try
      input = yaml.load input, schema: YANG_SPEC_SCHEMA if typeof input is 'string'
    catch e
      throw @error "invalid YIN syntax detected", e
    unless input instanceof Object
      throw @error "must pass in proper YIN input to parse"
    return input

module.exports = Compiler
