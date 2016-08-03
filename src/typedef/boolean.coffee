Typedef = require '../typedef'

module.exports =
  new Typedef 'boolean',
    construct: (value) ->
      return unless value?
      switch
        when typeof value is 'string' 
          unless value in [ 'true', 'false' ]
            throw new Error "[#{@tag}] #{value} must be 'true' or 'false'"
          value is 'true'
        when typeof value is 'boolean' then value
        else throw new Error "[#{@tag}] unable to convert '#{value}'"

