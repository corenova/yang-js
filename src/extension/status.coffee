Extension  = require '../extension'

module.exports =
  new Extension 'status',
    argument: 'value'
    resolve: -> @tag = @tag ? 'current'

