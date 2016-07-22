Extension  = require '../extension'

module.exports =
  new Extension 'extension',
    argument: 'extension-name' # required
    scope: 
      argument:    '0..1'
      description: '0..1'
      reference:   '0..1'
      status:      '0..1'
      
    construct: ->
      @source = @lookup 'extension', @tag
      
      # this is a bit hackish...
      #@compose = @origin?.compose?.bind @origin

