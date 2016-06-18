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

# private singleton instance of the "yang-v1-spec" Expressions
Origin =
  new Expression 'origin', 'yang-v1-spec',
    scope:
      extension: '0..n'
      typedef:   '0..n'
  .extends (require './yang-v1-extensions')...
  .extends (require './yang-v1-typedefs')...

# private singleton instance of the "yang-v1-lang" YANG module (using Origin)
Source = new Yang (fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yang'), 'utf-8'), Origin

# private singleton registry for stateful schema dependency processing (using Source)
Registry = new Yang 'composition registry;', Source

# primary method for the 'yang-js' module for creating schema driven Yang Expressions
yang = (schema, parent=Registry) -> new Yang schema, parent

#
# declare exports
#
exports = module.exports = (schema) -> (-> @eval arguments...).bind (yang schema)

# converts YANG schema text input or JS object into Yang Expression
#
# accepts: YANG schema text or JS object
# returns: Yang Expression
exports.parse = (schema, source) ->
  switch
    when typeof schema is 'string' then (yang schema, source)
    when schema instanceof Object
      keys = Object.keys schema
      unless keys.length is 1
        throw new Error "provided 'schema' object must contain a *single* key root property"

      source ?= Source
      key = keys[0]
      for ext in source.extension
        output = ext.transform? schema[key], key: key
        return new Yang output, source if output?

# convenience to add a new YANG module into the Registry by filename
exports.require = (filename, opts={}) ->
  # TODO: enable a special 'import' extension that handles dependent schemas if NOT found
  y = yang (fs.readFileSync filename, 'utf-8')
  Registry.extends y
  return y

# enable require to handle .yang extensions
exports.register = (opts={}) ->
  require.extensions?['.yang'] = (m, filename) ->
    m.exports = exports.require filename, opts
  return exports

# expose key class definitions
exports.Yang = Yang
exports.Expression = Expression
exports.Registry = Registry
