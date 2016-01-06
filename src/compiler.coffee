### yang-compiler

The **yang-compiler** class provides support for basic set of
YANG schema modeling language by using the built-in *extension* syntax
to define additional schema language constructs.

The compiler only supports bare minium set of YANG statements and
should be used only to generate a new compiler such as [yangforge](./yangforge.coffee)
which implements the version 1.0 of the YANG language specifications.

###

synth = require 'data-synth'

class YangCompiler

  define: (type, key, value) ->
	_define = (to, type, key, value) ->
	  [ prefix..., key ] = key.split ':'
	  if prefix.length > 0
		to[prefix[0]] ?= {}
		base = to[prefix[0]]
	  else
		base = to
	  synth.copy base, synth.objectify "#{type}.#{key}", value
	exists = @resolve type, key, false
	switch
	  when not exists?
		_define @source, arguments...
	  when synth.instanceof exists
		exists.merge value
	  when synth.instanceof value
		_define @source, type, key, value.override exists
	  when exists.constructor is Object
		synth.copy exists, value
	return undefined

  resolve: (type, key, warn=true) ->
	source = @source
	unless key?
	  # TODO: we may want to grab other definitions from imported modules here
	  return source?[type]

	[ prefix..., key ] = key.split ':'
	while source?
	  base = if prefix.length > 0 then source[prefix[0]] else source
	  match = base?[type]?[key]
	  return match if match?
	  source = source.parent

	console.log "[resolve] unable to find #{type}:#{key}" if warn
	return undefined

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

###
The `parse` function performs recursive parsing of passed in statement
and sub-statements and usually invoked in the context of the
originating `compile` function below.  It expects the `statement` as
an Object containing prf, kw, arg, and any substmts as an array.  It
currently does NOT perform semantic validations but rather simply
ensures syntax correctness and building the JS object tree structure.
###

  normalize = (obj) -> ([ obj.prf, obj.kw ].filter (e) -> e? and !!e).join ':'

  parse: (input, parser=(require 'yang-parser')) ->
    try
      input = (parser.parse input) if typeof input is 'string'
    catch e
      e.offset = 30 unless e.offset > 30
      offender = input.slice e.offset-30, e.offset+30
      offender = offender.replace /\s\s+/g, ' '
      throw @error "[yang-compiler:parse] invalid YANG syntax detected (file not found?)", offender

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

###
The `preprocess` function is the intermediary method of the compiler
which prepares a parsed output to be ready for the `compile`
operation.  It deals with any `include` and `extension` statements
found in the parsed output in order to prepare the context for the
`compile` operation to proceed smoothly.
###

  extractKeys = (x) -> if x instanceof Object then (Object.keys x) else [x].filter (e) -> e? and !!e

  fork: (f, args...) -> f?.apply? (new @constructor), args

  preprocess: (schema, source={}, scope) ->
    unless scope?
      # first merge source extension using parent extensions if available
      basis = synth.copy {}, source.parent?.extension
      source.extension = synth.copy basis, source.extension
      unless (Object.keys source.extension).length > 0
        throw @error "cannot preprocess requested schema without source.extension scope"
      return @fork arguments.callee, schema, source, source.extension

    @source = source
    schema = (@parse schema) if typeof schema is 'string'
    unless schema instanceof Object
      throw @error "must pass in proper 'schema' to preprocess"

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
          for ext of extension when ext isnt 'argument'
            delete extension[ext]
          @define 'extension', name, extension
        delete schema.extension
        console.log "[preprocess:#{source.name}] found #{extensions.length} new extension(s)"
        continue

      ext = @resolve 'extension', key
      unless (ext instanceof Object)
        throw @error "[preprocess:#{source.name}] encountered unresolved extension '#{key}'", schema
      constraint = scope[kw]

      unless ext.argument?
        # TODO - should also validate constraint for input/output
        @preprocess val, source, ext
        ext.preprocess?.call? this, key, val, schema
      else
        args = (extractKeys val)
        valid = switch constraint
          when '0..1','1' then args.length <= 1
          when '1..n' then args.length > 1
          else true
        unless valid
          throw @error "[preprocess:#{source.name}] constraint violation for '#{key}' (#{args.length} != #{constraint})", schema
        for arg in args
          params = if val instanceof Object then val[arg]
          argument = switch
            when typeof arg is 'string' and arg.length > 50
              ((arg.replace /\s\s+/g, ' ').slice 0, 50) + '...'
            else arg
          source.name ?= arg if key in [ 'module', 'submodule' ]
          console.log "[preprocess:#{source.name}] #{key} #{argument} " + if params? then "{ #{Object.keys params} }" else ''
          params ?= {}
          @preprocess params, source, ext
          try
            ext.preprocess?.call? this, arg, params, schema
          catch e
            console.error e
            throw @error "[preprocess:#{source.name}] failed to preprocess '#{key} #{arg}'", args

    return schema

###
The `compile` function is the primary method of the compiler which
takes in YANG schema input and produces JS output representing the
input schema as meta data hierarchy.

It accepts following forms of input
* YANG schema text string
* function that will return a YANG schema text string
* Object output from `parse`

The compilation process can compile any partials or complete
representation of the schema and recursively compiles the data tree to
return synthesized object hierarchy.
###

  compile: (schema, source={}, scope) ->
    return @fork arguments.callee, schema, source, true unless scope?
    @source = source

    schema = (schema.call this) if schema instanceof Function
    schema = (@preprocess schema, source) unless source.extension?
    unless schema instanceof Object
      throw @error "must pass in proper 'schema' to compile"

    output = {}
    for key, val of schema
      continue if key is 'extension'

      ext = @resolve 'extension', key
      unless (ext instanceof Object)
        throw @error "[compile:#{source.name}] encountered unknown extension '#{key}'", schema

      # here we short-circuit if there is no 'construct' for this extension
      continue unless ext.construct instanceof Function

      unless ext.argument?
        console.log "[compile:#{source.name}] #{key} " + if val instanceof Object then "{ #{Object.keys val} }" else val
        children = @compile val, source, ext
        output[key] = ext.construct.call this, key, val, children, output, ext
        delete output[key] unless output[key]?
      else
        for arg in (extractKeys val)
          params = if val instanceof Object then val[arg]
          console.log "[compile:#{source.name}] #{key} #{arg} " + if params? then "{ #{Object.keys params} }" else ''
          params ?= {}
          children = @compile params, source, ext
          try
            output[arg] = ext.construct.call this, arg, params, children, output, ext
            delete output[arg] unless output[arg]?
          catch e
            console.error e
            throw @error "[compile:#{source.name}] failed to compile '#{key} #{arg}'", schema
    return output

module.exports = YangCompiler
