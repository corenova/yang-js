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

YANG_V1_LANG_SCHEMA = fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yang'), 'utf-8'
YANG_V1_LANG_SPEC   = fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yin'), 'utf-8'

Yin  = require './yin'
Yang = require './yang'

#
# declare exports
#
exports = module.exports = yang = (schema, origin=exports.Origin) -> new Yang schema, origin

# declare a singleton instance of the default "yang-v1-lang" module
exports.Origin = yang YANG_V1_LANG_SCHEMA, (new Yin YANG_V1_LANG_SPEC)

# expose key class definitions
exports.Yin    = Yin
exports.Yang   = Yang

# enable require to handle .yin and .yang extensions
exports.register = ->
  require.extensions?['.yang'] = (m, filename) ->
    m.exports = yang (fs.readFileSync filename, 'utf-8')

  require.extensions?['.yin'] = (m, filename) ->
    m.exports = yang.Origin.merge (Yin.load filename)

# produces new compiled object instance generated for input data based
# on passed in schema
#
# accepts: JS object
# returns: new Object containing compiled schema definitions
exports.load = (obj, opts={}) ->
  yang().merge(schemas...).transform data

# converts passed in JS object back into YANG schema (if possible)
#
# accepts: JS object
# returns: YANG schema text
exports.dump = (obj={}, space=2) -> obj.toString space: space

# converts YANG schema text input into JS object representation
#
# accepts: YANG schema text
# returns: JS object
exports.parse = (schema) -> (yang schema).toObject()
