Extension = require '../extension'

# use special built-in handling inside Extension itself
module.exports =
  new Extension 'extension',
    argument: 'extension-name'
    scope:
      argument:    '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
    resolve: ->
