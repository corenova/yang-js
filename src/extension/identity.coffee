Extension  = require '../extension'

module.exports =
  new Extension 'identity',
    scope:
      base:        '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
    # TODO: resolve 'base' statements
    resolve: -> 
      if @base?
        @lookup 'identity', @base.tag

