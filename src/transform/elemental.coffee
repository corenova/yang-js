Element = require '../element'

class Container extends Element
  constructor: (schema, data) ->
    super
    @[k] = v for k, v of data when k of this

class Leaf extends Element
  constructor: (schema, data) ->
    super
    Object.defineProperty this, '__value__',
      writable: true
      value: schema.default
    @__value__ = data
  valueOf: -> @__value__

exports = module.exports = (expr, params, opts={}) ->
  exports.map[expr.kw]?.call? expr, params

exports.map =
  container: (params) ->
    prop = (Container).bind null, params
    prop.enumerable = true
    prop.configurable = true
    return prop

  feature: (params) -> null

  leaf: (params) ->
    prop = (Leaf).bind null, params
    prop.enumerable = true
    prop.configurable = true
    return prop

  type: (params) ->
