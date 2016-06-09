### yang-js
#
# The **yang-js** module provides support for basic set of YANG schema
# modeling language by using the built-in *extension* syntax to define
# additional schema language constructs.
#
###
console.debug ?= console.log if process.env.yang_debug?

fs   = require 'fs'
path = require 'path'

Yang       = require './yang'
Expression = require './expression'

# private singleton instance of the "yang-v1-lang" YIN module
#Origin = new Yin (fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yin'), 'utf-8')
Origin =
  new Expression 'yang-v1-spec',
    kind: 'origin'
    scope:
      extension: '0..n'
      typedef:   '0..n'
  .extends (require './yang-v1-extensions')...
  .extends (require './yang-v1-typedefs')...

# private singleton instance of the "yang-v1-lang" YANG module (using Origin)
Source = new Yang (fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yang'), 'utf-8'), Origin

# primary method for the 'yang-js' module for creating schema driven Yang Expressions
yang = (schema, opts={}) ->
  opts.parent ?= Source
  opts.wrap ?= true
  schema = (new Yang schema, opts.parent)
  return schema unless opts.wrap is true
  expr = (-> @eval arguments...).bind schema
  expr.origin = schema
  return expr

#
# declare exports
#
exports = module.exports = yang

# expose key class definitions
exports.Yang = Yang
exports.Expression = Expression

# produces new compiled object instance generated for input data based
# on passed in schema
#
# accepts: JS object
# returns: new Object containing compiled schema definitions
exports.load = (obj, opts={}) ->
  schema = switch
    when opts.schema instanceof Yang then opts.schema
    when opts.schema?
      try (yang schema) catch e then console.error e; throw e
    else throw new Error "must supply 'schema' to use for load"
  return schema.create obj

# converts passed in JS object back into YANG schema (if possible)
#
# accepts: JS object
# returns: YANG schema text
exports.dump = (obj, opts={}) ->
  output = switch
    when obj instanceof Yang then obj.toString opts
    when obj?.yang instanceof Yang then obj.yang.toString opts
    else throw new Error "incompatible object to dump to YANG schema string"
  switch opts.encoding
    when 'base64' then (new Buffer output).toString 'base64'
    else output
  # placeholder:
  # (new Buffer some-string, 'base64').toString 'binary'

      
# converts YANG schema text input into JS object representation
#
# accepts: YANG schema text
# returns: JS object
exports.parse = (schema) ->
  try (yang schema, wrap: false).toObject() catch e then console.error e; throw e

##
# Registry (for stateful schema dependency processing)
#
# expose an internal Registry for collecting `required` assets
exports.Registry = yang """
  composition registry {
    description "internal registry containing one or more YANG module(s)";
  }
""", wrap: false

# convenience to add a new YANG module into the Registry
exports.require = (filename, opts={}) ->
  # TODO: enable a special 'import' extension that handles dependent schemas if NOT found

  schema = (fs.readFileSync filename, 'utf-8')
  x = yang schema, wrap: false
  exports.Registry.extends x
  return x

# enable require to handle .yang extensions
exports.register = (opts={}) ->
  require.extensions?['.yang'] = (m, filename) ->
    m.exports = exports.require filename, opts
  return exports
