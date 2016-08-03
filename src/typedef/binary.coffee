Typedef = require '../typedef'

module.exports =
  new Typedef 'binary',
    construct: (value) ->
      return unless value?
      unless value instanceof Object
        throw new Error "[#{@tag}] unable to convert '#{value}'"
      value
