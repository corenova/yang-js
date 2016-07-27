Extension  = require '../extension'

module.exports =
  new Extension 'require-instance',
    argument: 'value'
    resolve: -> @tag = (@tag is true or @tag is 'true')

