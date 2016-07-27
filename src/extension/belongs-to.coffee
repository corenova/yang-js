Extension  = require '../extension'

module.exports =
  new Extension 'belongs-to',
    argument: 'module-name'
    scope:
      prefix: '1'

    resolve: ->
      @module = @lookup 'module', @tag
      unless @module?
        throw @error "unable to resolve '#{@tag}' module"
