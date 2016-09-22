### yang-js
#
# The **yang-js** module provides support for basic set of YANG schema
# modeling language by using the built-in *extension* syntax to define
# additional schema language constructs.
#
###
console.debug ?= console.log if process.env.yang_debug?

Yang = require './yang'
Yang.use require('./lang/extensions'), require('./lang/typedefs')

exports = module.exports = Yang

# automatically register if require.extensions available
require.extensions?['.yang'] ?= (m, filename) ->
  m.exports = Yang.require filename
