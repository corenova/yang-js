Extension  = require '../extension'

module.exports =
  new Extension 'revision',
    argument: 'date'
    scope:
      description: '0..1'
      reference:   '0..1'

