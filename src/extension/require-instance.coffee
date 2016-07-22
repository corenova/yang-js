Extension  = require '../extension'

module.exports =
  new Extension 'require-instance',
    resolve: -> @tag = (@tag is true or @tag is 'true')

