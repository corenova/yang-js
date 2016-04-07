#
# Yin - calm internally supportive definitions and generator
#

yaml     = require 'js-yaml'
coffee   = require 'coffee-script'
parser   = require 'yang-parser'
path     = require 'path'

YANG_SPEC_SCHEMA = yaml.Schema.create [

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
      console.debug? "processing !yang using: #{data}"
      (new Yin).parse data
]

Origin = require './origin'
Yang   = require './yang'
DS     = require 'data-synth'

class Yin extends Origin
  constructor: ->
    super
    @set 'synthesizer', DS
    unless (Yin::resolve.call this, 'extension')?
      @define 'extension',
        specification:
          argument: 'name',
          preprocess: (arg, params) -> @origin.define 'specification', arg, params
        module:
          argument: 'name'
    return this

  #### PRIMARY API METHODS ####
  # produces new compiled object instances generated from provided
  # schema(s)
  #
  # accepts: variable arguments of YANG/YAML schema/specification string(s)
  # returns: new Yang object containing schema compiled object(s)
  load: ->
    input = [].concat arguments...
    unless input.length > 0
      throw @error "no input schema(s) to load"
    new Yang ((new Yin this).use input)

  # converts passed in JS object back into YANG schema (if possible)
  #
  # accepts: JS object
  # returns: YANG schema text
  dump: (obj=this, opts={}) ->
    output = ''
    obj = switch
      when obj instanceof Yang   then obj.origin.map
      when obj instanceof Origin then obj.map
      else obj
    for k, v of obj
      ext = @resolve 'extension', switch
        when v instanceof Function and !!v.yang then v.yang
        else k
      continue unless ext?
      output += switch
        when v instanceof Function
          (ext.represent?.call? this, v, k) ? ''
        when v instanceof Object
          x = ""
          for arg, params of v
            x += "#{k} #{arg}"
            if params instanceof Object
              x += "{#{@dump params}}"
            else
              x += ';'
          x
        when ext.argument is 'text' or ext.argument.text?
          "#{k} \"#{v}\";"
        else
          "#{k} #{v};"
    # TODO: handle 'opts.indent' here

    return output

  #### SECONDARY API METHODS ####

  # process schema/spec input(s) and defines results inside current
  # Yin instance
  #
  # accepts: variable arguments of YANG/YAML schema/specification string(s)
  # returns: current Yin instance (with updated definitions)
  use: ->
    ([].concat arguments...).forEach (x) => @set (@compile x)
    return this

  error: (msg, context=this) ->
    res = super
    res.name = 'YinError'
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
        console.debug? "[Yin:compile:#{map.name}] #{key} " + if val instanceof Object then "{ #{Object.keys val} }" else val
        children = Yin::compile.call this, val, map, ext
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
          console.debug? "[Yin:compile:#{map.name}] #{key} #{arg} " + if params? then "{ #{Object.keys params} }" else ''
          params ?= {}
          children = Yin::compile.call this, params, map, ext
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
      if key in [ 'module', 'submodule' ]
        map.name = (extractKeys val)[0]
        # TODO: what if map was supplied as an argument?
        console.debug? "[Yin:preprocess:#{map.name}] loading specification for '#{map.name}'"
        map.set (Yin::resolve.call this, 'specification', map.name, warn: false)

      ext = map.resolve 'extension', key
      unless (ext instanceof Object)
        throw @error "encountered unresolved extension '#{key}'", schema

      unless ext.argument?
        # TODO - should also validate constraint for input/output
        Yin::preprocess.call this, val, map
        ext.preprocess?.call? map, key, val, schema, this
      else
        args = (extractKeys val)
        if key is 'extension'
          console.debug? "[Yin:preprocess:#{map.name}] found #{args.length} new extension(s)"

        for arg in args
          params = if val instanceof Object then val[arg]
          argument = switch
            when typeof arg is 'string' and arg.length > 50
              ((arg.replace /\s\s+/g, ' ').slice 0, 50) + '...'
            else arg
          console.debug? "[Yin:preprocess:#{map.name}] #{key} #{argument} " + if params? then "{ #{Object.keys params} }" else ''
          params ?= {}
          unless key in [ 'extension', 'specification' ]
            Yin::preprocess.call this, params, map
          try
            ext.preprocess?.call? map, arg, params, schema, this
          catch e
            console.error e
            throw @error "failed to preprocess '#{key} #{arg}'", args

    return schema: schema, map: map

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
      # try and see if it is YAML input string?
      try
        return yaml.load input, schema: YANG_SPEC_SCHEMA
      catch e
        # wasn't proper YAML either...
      e.offset = 30 unless e.offset > 30
      offender = input.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "invalid YANG/YAML syntax detected", offender

    unless input instanceof Object
      throw @error "must pass in proper input to parse"

    params =
      (Yin::parse.call this, stmt for stmt in input.substmts)
      .filter (e) -> e?
      .reduce ((a, b) -> Yang.copy a, b, true), {}
    params = null unless Object.keys(params).length > 0

    @objectify "#{normalize input}", switch
      when not params? then input.arg
      when not !!input.arg then params
      else "#{input.arg}": params

module.exports = Yin
