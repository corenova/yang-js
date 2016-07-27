### yang-js
#
# The **yang-js** module provides support for basic set of YANG schema
# modeling language by using the built-in *extension* syntax to define
# additional schema language constructs.
#
###
console.debug ?= console.log if process.env.yang_debug?

Compiler = require './compiler'
compiler = new Compiler 'yang-1.1', [
  
  # built-in extensions
  require './extension/action'
  require './extension/anydata'
  require './extension/argument'
  require './extension/augment'
  require './extension/base'
  require './extension/belongs-to'
  require './extension/bit'
  require './extension/case'
  require './extension/choice'
  require './extension/config'
  require './extension/contact'
  require './extension/container'
  require './extension/default'
  require './extension/description'
  require './extension/deviate'
  require './extension/deviation'
  require './extension/enum'
  require './extension/error-app-tag'
  require './extension/error-message'
  require './extension/extension'
  require './extension/feature'
  require './extension/fraction-digits'
  require './extension/grouping'
  require './extension/identity'
  require './extension/if-feature'
  require './extension/import'
  require './extension/include'
  require './extension/input'
  require './extension/key'
  require './extension/leaf'
  require './extension/leaf-list'
  require './extension/length'
  require './extension/list'
  require './extension/mandatory'
  require './extension/max-elements'
  require './extension/min-elements'
  require './extension/modifier'
  require './extension/module'
  require './extension/must'
  require './extension/notification'
  require './extension/ordered-by'
  require './extension/organization'
  require './extension/output'
  require './extension/path'
  require './extension/pattern'
  require './extension/prefix'
  require './extension/presence'
  require './extension/range'
  require './extension/reference'
  require './extension/refine'
  require './extension/require-instance'
  require './extension/revision'
  require './extension/revision-date'
  require './extension/rpc'
  require './extension/status'
  require './extension/submodule'
  require './extension/type'
  require './extension/typedef'
  require './extension/unique'
  require './extension/uses'
  require './extension/value'
  require './extension/when'
  require './extension/yang-version'
  require './extension/yin-element'

  # built-in typedefs
  require './typedef/boolean'
  require './typedef/empty'
  require './typedef/binary'
  require './typedef/integer'
  require './typedef/decimal64'
  require './typedef/string'
  require './typedef/union'
  require './typedef/enumeration'
  require './typedef/identityref'
  require './typedef/instance-identifier'
  require './typedef/leafref'

]

#
# declare exports
#
exports = module.exports = (schema) ->
  (-> @eval arguments...).bind (compiler.parse schema)

for k, v of compiler when k isnt 'constructor'
  exports[k] = switch
    when typeof v instanceof Function then v.bind compiler
    else v
      
# enable Node.js require to handle .yang extensions
exports.register = (opts={}) ->
  require.extensions?['.yang'] ?= (m, filename) ->
    m.exports = compiler.import filename, opts
  return exports

exports.Compiler  = Compiler
exports.Yang      = require './yang'
exports.Extension = require './extension'
