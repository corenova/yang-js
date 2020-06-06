Expression = require './expression'

class Typedef extends Expression
  constructor: ->
    super 'typedef', arguments...

  @property 'primitive', get: -> @tag
  @property 'convert', get: -> @construct ? (x) -> x

module.exports = Typedef
