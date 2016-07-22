Typedef = require '../typedef'

module.exports =
  # TODO
  new Typedef 'identityref',
    evaluate: (value) ->
      return unless value?
      unless @base? and typeof @base.tag is 'string'
        throw new Error "[#{@tag}] must reference 'base' identity"
      identity = @base.tag
      # return a computed function (runs during get)
      func = ->
        match = @expr.lookup 'identity', value
        # TODO - need to figure out how to return namespace value...
        unless (match? and identity is match.base?.tag)
          new Error "[#{@tag}] #{@name} is invalid for '#{value}'"
        else
          value
      func.computed = true
      return func

