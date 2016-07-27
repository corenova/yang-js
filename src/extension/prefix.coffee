Extension  = require '../extension'

module.exports =
  new Extension 'prefix',
    argument: 'value'
    resolve: -> # should validate prefix naming convention

