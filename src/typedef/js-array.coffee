Typedef = require '../typedef'

module.exports =
  new Typedef 'js-array',
    evaluate: (value) ->
      return unless value?
      unless value instanceof Array
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      value
          
