Extension  = require '../extension'

module.exports =
  new Extension 'belongs-to',
   scope:
     prefix: '1'

   construct: ->
     @module = @lookup 'module', @tag
     unless @module?
       throw @error "unable to resolve '#{@tag}' module"
