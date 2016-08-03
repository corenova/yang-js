Typedef = require '../typedef'

module.exports =
  # TODO
  new Typedef 'identityref',
    construct: (value) ->
      return unless value?
      unless @base? and typeof @base.tag is 'string'
        throw new Error "[#{@tag}] must reference 'base' identity"
      base = @base.tag
      
      unless @base? and typeof @base.tag is 'string'
        throw new Error "[#{@tag}] must reference 'base' identity"

      return value # XXX - bypass verification for now
      
      # fix this later
      base = @base.tag
      match = origin.lookup 'identity', value
      unless match?
        imports = (origin.lookup 'import') ? []
        for m in imports
          match = m.module.lookup 'identity', value
          break if match? 

      console.debug? "base: #{base} match: #{match} value: #{value}"
      # TODO - need to figure out how to return namespace value...
      # unless (match? and base is match.base?.tag)
      #   throw new Error "[#{@tag}] identityref is invalid for '#{value}'"
      value
