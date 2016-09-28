Expression = require './expression'

class Typedef extends Expression
  constructor: ->
    super 'typedef', arguments...
    
  @property 'convert', get: -> @construct ? (x) -> x

module.exports = Typedef
