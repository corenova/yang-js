Extension  = require '../extension'

module.exports =
  new Extension 'default',
    evaluate: (data) -> data ? @tag
