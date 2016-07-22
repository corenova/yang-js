Extension  = require '../extension'

module.exports =
  new Extension 'status',
    resolve: -> @tag = @tag ? 'current'

