Typedef = require '../typedef'

module.exports =
  new Typedef 'binary',
    evaluate: (value) ->
      return unless value?
      unless value instanceof Object
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      value
