Extension  = require '../extension'

module.exports =
  # TODO
  new Extension 'modifier',
    resolve: -> @tag = @tag is 'invert-match'
