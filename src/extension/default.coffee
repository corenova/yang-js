Extension  = require '../extension'

module.exports =
  new Extension 'default',
    argument: 'value'
    construct: (data) -> data ? @tag
