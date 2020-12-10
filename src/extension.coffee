Expression = require './expression'

class Extension extends Expression
  logger: require('debug')('yang:extension')
  @scope =
    argument:    '0..1'
    description: '0..1'
    reference:   '0..1'
    status:      '0..1'
  constructor: (name, spec={}) ->
    spec.scope ?= {}
    super 'extension', name, spec

module.exports = Extension
