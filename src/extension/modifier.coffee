Extension  = require '../extension'

module.exports =
  # TODO
  new Extension 'modifier',
    argument: 'value'
    resolve: -> @tag = @tag is 'invert-match'
