Extension  = require '../extension'

module.exports =
  # TODO
  new Extension 'when',
    argument: 'condition'
    scope:
      description: '0..1'
      reference:   '0..1'

