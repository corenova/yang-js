Typedef = require '../typedef'

module.exports =
  new Typedef 'js-function',
    evaluate: (value) ->
      return unless value?
      unless value instanceof Function
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      value
