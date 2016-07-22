Extension  = require '../extension'

module.exports =
  # TODO
  new Extension 'deviation',
    scope:
      description: '0..1'
      deviate:     '1..n'
      reference:   '0..1'
