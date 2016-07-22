Extension  = require '../extension'

module.exports =
  new Extension 'argument',
    argument: 'arg-type' # required?
    scope:
      'yin-element': '0..1'
