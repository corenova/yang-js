Extension  = require '../extension'

# TODO
module.exports =
  new Extension 'bit',
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      position:    '0..1'
