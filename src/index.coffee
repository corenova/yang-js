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

YANG_V1_LANG = [
  fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yaml'), 'utf-8'
  fs.readFileSync (path.resolve __dirname, '../yang-v1-lang.yang'), 'utf-8'
]

#
# declare exports
#
exports = module.exports = (new Yin).use YANG_V1_LANG...
exports.Yin    = Yin
exports.Yang   = require './yang'
exports.Origin = require './origin'
