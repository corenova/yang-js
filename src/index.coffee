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
Registry =
  new Expression 'registry', 'yang-v1-registry',
    parent: Source
    scope:
      module: '0..n'

# primary method for the 'yang-js' module for creating schema driven Yang Expressions
yang = (schema, parent=Registry) -> new Yang schema, parent

#
# declare exports
#
exports = module.exports = (schema) -> (-> @eval arguments...).bind (yang schema)

# converts YANG schema text input into Yang Expression
#
# accepts: YANG schema text
# returns: Yang Expression
exports.parse = (schema) -> (yang schema)

# composes arbitrary JS object into Yang Expression
#
# accepts: JS object
# returns: Yang Expression

exports.compose = (name, data, opts={}) ->
  source = opts.source ? Source
  # explict compose
  if opts.kind?
    ext = source.lookup 'extension', opts.kind
    unless ext instanceof Expression
      throw new Error "unable to find requested '#{opts.kind}' extension"
    return new Yang (ext.compose data, key: name), source
  
  # implicit compose (dynamic discovery)
  for ext in source.extension when ext.compose instanceof Function
    console.debug? "checking data if #{ext.tag}"
    try return new Yang (ext.compose data, key: name), source

# convenience to add a new YANG module into the Registry by filename
exports.require = (filename, opts={}) ->
  filename = path.resolve filename
  basedir  = path.dirname filename
  try yexpr = yang (fs.readFileSync filename, 'utf-8')
  catch e
    console.debug? e
    throw e unless e.name is 'ExpressionError' and e.context?.kind is 'import'
    Registry.extends (arguments.callee (path.resolve basedir, "#{e.context.tag}.yang"))
    yexpr = arguments.callee filename, opts
  Registry.extends yexpr
  return yexpr

# enable require to handle .yang extensions
exports.register = (opts={}) ->
  require.extensions?['.yang'] ?= (m, filename) ->
    m.exports = exports.require filename, opts
  return exports

# expose key class definitions
exports.Yang = Yang
exports.Expression = Expression
exports.Registry = Registry
