#
# Yin - specification for YANG language extensions
#

# external dependencies
yaml    = require 'js-yaml'
coffee  = require 'coffee-script'

# local dependencies
Expression = require './expression'

YIN_SCHEMA = yaml.Schema.create [

  new yaml.Type '!coffee',
    kind: 'scalar'
    resolve:   (data) -> typeof data is 'string'
    construct: (data) -> coffee.eval? data

  new yaml.Type '!coffee/function',
    kind: 'scalar'
    resolve:   (data) -> typeof data is 'string'
    construct: (data) -> coffee.eval? data
    predicate: (obj) -> obj instanceof Function
    represent: (obj) -> obj.toString()

  new yaml.Type '!yang/extension',
    kind: 'mapping'
    resolve:   (data) -> typeof data is 'object'
    construct: (data) -> new Expression 'extension', data

  new yaml.Type '!yang/typedef',
    kind: 'mapping'
    resolve:   (data) -> typeof data is 'object'
    construct: (data) -> new Expression 'typedef', data

]

# represents YIN specification
class Yin extends Expression

  constructor: (schema, data={}) ->
    try
      schema = yaml.load schema, schema: YIN_SCHEMA if typeof schema is 'string'
    catch e
      console.warn e
      throw @error "invalid YIN schema syntax detected", e
      
    unless schema instanceof Object
      throw @error "must pass in proper YIN schema to parse"
      
    schema[k] = [ v ] for k, v of schema when v instanceof Expression
    super 'yin-specification', schema

  # Yin has mapping of arg -> kw (reverse of Yang)
  resolve: (kw, arg) ->
    return super unless arg?

    console.debug? "[Yin:resolve] #{kw} #{arg}"
    if (@hasOwnProperty arg) and @[arg] instanceof Array
      for expr in @[arg] when expr? and expr.kw is kw
        return expr
    
    return @parent?.resolve? arguments...

exports = module.exports = Yin
exports.load = ->
exports.dump = ->
