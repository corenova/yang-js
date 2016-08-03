Typedef = require '../typedef'

module.exports =
  new Typedef 'union',
    construct: (value) ->
      unless @type?
        throw new Error "[#{@tag}] must contain one or more type definitions"
      for type in @type
        try return type.convert value
        catch then continue
      throw new Error "[#{@tag}] unable to find matching type for '#{value}' within: #{@type}"
      
