Extension  = require '../extension'

module.exports =
  new Extension 'revision',
    scope:
      description: '0..1'
      reference:   '0..1'

