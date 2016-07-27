# Typedef - represents a Yang Typedef

Element = require './element'

class Typedef extends Element
  constructor: (name, spec={}) ->
    unless spec instanceof Object
      throw @error "must supply 'spec' as object"

    super 'typedef', name
    
    Object.defineProperties this,
      construct: value: spec.construct ? (x) -> x
      schema:    value: spec.schema

  convert: (value) -> @construct value

module.exports = Typedef
