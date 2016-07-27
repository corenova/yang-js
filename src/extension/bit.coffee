Extension  = require '../extension'

# TODO
module.exports =
  new Extension 'bit',
    argument: 'name'
    scope:
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      position:    '0..1'
