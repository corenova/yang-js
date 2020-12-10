Expression = require './expression'

class Typedef extends Expression
  logger: require('debug')('yang:typedef')
  constructor: ->
    super 'typedef', arguments...

  @property 'basetype', get: -> @tag
  @property 'convert', get: -> @construct ? (x) -> x

module.exports = Typedef
