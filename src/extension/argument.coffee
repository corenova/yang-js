Extension  = require '../extension'

module.exports =
  new Extension 'argument',
    argument: 'arg-type'
    scope:
      'yin-element': '0..1'
