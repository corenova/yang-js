Extension  = require '../extension'

module.exports =
  new Extension 'if-feature',
    resolve: ->
      unless (@lookup 'feature', @tag)?
        console.warn "should be turned off..."
        #@define 'status', off

