Typedef = require '../typedef'

module.exports =
  new Typedef 'decimal64',
    evaluate: (value) ->
      return unless value?
      if Number.isNaN (Number value)
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      if typeof value is 'string' and !value
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      switch
        when typeof value is 'string' then Number value
        when typeof value is 'number' then value
        else throw new Error "[#{@tag}] type violation for #{value}"
