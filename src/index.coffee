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

Yin  = require './yin'
Yang = require './yang'

# private singleton instance of the "yang-v1-lang" YIN module
Origin = new Yin (fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yin'), 'utf-8')

# private singleton instance of the "yang-v1-lang" YANG module (using Origin)
Source = new Yang (fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yang'), 'utf-8'), parent: Origin

# primary method for the 'yang-js' module for creating schema driven Yang Expressions
yang = (schema, data={}) -> data.parent ?= Source; new Yang schema, data

#
# declare exports
#
exports = module.exports = yang

# expose key class definitions
exports.Yin  = Yin
exports.Yang = Yang

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
  try (yang schema).toObject() catch e then console.error e; throw e

##
# Registry (for stateful schema dependency processing)
#
# expose an internal Registry for collecting `required` assets
exports.Registry = yang """
  composition registry {
    description "internal registry containing one or more YANG module(s)";
  }
"""

# convenience to add a new YANG module into the Registry
exports.require = -> exports.Registry.extend arguments...

# enable require to handle .yin and .yang extensions
exports.register = ->
  require.extensions?['.yang'] = (m, filename) ->
    m.exports = exports.require (fs.readFileSync filename, 'utf-8')

  require.extensions?['.yin'] = (m, filename) ->
    m.exports = exports.require (new Yin (fs.readFileSync filename, 'utf-8'))

