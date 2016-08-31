### yang-js
#
# The **yang-js** module provides support for basic set of YANG schema
# modeling language by using the built-in *extension* syntax to define
# additional schema language constructs.
#
###
console.debug ?= console.log if process.env.yang_debug?

Yang       = require './core/yang'
Extension  = require './core/extension'
Typedef    = require './core/typedef'

Yang.use Extension.builtins, Typedef.builtins

exports = module.exports = Yang

# expose key class definitions
exports.Extension = Extension
exports.Typedef   = Typedef
exports.Property  = require './core/property'
exports.Model     = require './core/model'
