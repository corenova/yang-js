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

<<<<<<< HEAD
for k, v of compiler when k isnt 'constructor'
  exports[k] = switch
    when typeof v instanceof Function then v.bind compiler
    else v
      
# enable Node.js require to handle .yang extensions
=======
exports.bundle = (schema...) ->

exports.resolve = (from..., name) ->
  return null unless typeof name is 'string'
  dir = from = switch
    when from.length then from[0]
    else path.resolve()
  while not found? and dir not in [ '/', '.' ]
    console.debug? "resolving #{name} in #{dir}/package.json"
    try
      found = require("#{dir}/package.json").models[name]
      dir   = path.dirname require.resolve("#{dir}/package.json")
    dir = path.dirname dir unless found?
  file = switch
    when found? and /^[\.\/]/.test found then path.resolve dir, found
    when found? then @resolve found, name
  file ?= path.resolve from, "#{name}.yang"
  console.debug? "checking if #{file} exists"
  return if fs.existsSync file then file else null
      
# convenience to add a new YANG module into the Registry by filename
exports.require = (name, opts={}) ->
  opts.basedir ?= ''
  opts.resolve ?= true
  extname  = path.extname name
  filename = path.resolve opts.basedir, name
  basedir  = path.dirname filename
  
  try model = switch extname
    when '.yang' then yang (fs.readFileSync filename, 'utf-8')
    when ''      then require (@resolve name)
    else require filename
  catch e
    console.debug? e
    throw e unless opts.resolve and e.name is 'ExpressionError' and e.context.kind is 'import'

    # try to find the dependency module for import
    dependency = @resolve basedir, e.context.tag
    unless dependency?
      e.message = "unable to auto-resolve '#{e.context.tag}' dependency module"
      throw e

    # update Registry with the dependency module
    Registry.update (@require dependency)
    
    # try the original request again
    model = @require arguments...
    
  return Registry.update model

# enable require to handle .yang extensions
>>>>>>> master
exports.register = (opts={}) ->
  require.extensions?['.yang'] ?= (m, filename) ->
    m.exports = compiler.import filename, opts
  return exports

<<<<<<< HEAD
exports.Compiler  = Compiler
exports.Yang      = require './yang'
exports.Extension = require './extension'
=======
# expose key class definitions
exports.Yang = Yang
exports.Registry  = Registry
exports.XPath = require './xpath'
>>>>>>> master
