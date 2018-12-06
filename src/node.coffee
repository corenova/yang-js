### yang-js
#
# The **yang-js** module provides support for basic set of YANG schema
# modeling language by using the built-in *extension* syntax to define
# additional schema language constructs.
#
###
Yang = require './yang'
Yang.use require('./lang/extensions'), require('./lang/typedefs')

exports = module.exports = Yang
exports.Extension = require './extension'
exports.Typedef   = require './typedef'
exports.Store     = require './store'
exports.Model     = require './model'
exports.Property  = require './property'

# automatically register if require.extensions available
require.extensions?['.yang'] ?= (m, filename) ->
  m.exports = Yang.import filename
