### yang-js
#
# The **yang-js** module provides support for basic set of YANG schema
# modeling language by using the built-in *extension* syntax to define
# additional schema language constructs.
#
###
console.debug ?= console.log if process.env.yang_debug?

Yang       = require './yang'
Extension  = require './core/extension'
Typedef    = require './core/typedef'

Yang.use Extension.builtins, Typedef.builtins

# automatically register if require.extensions available
require.extensions?['.yang'] ?= (m, filename) ->
  m.exports = Yang.require filename

exports = module.exports = Yang

# expose key class definitions
exports.Extension = Extension
exports.Typedef   = Typedef
exports.Property  = require './property'
exports.Model     = require './model'
