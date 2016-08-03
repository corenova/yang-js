Typedef = require '../typedef'

module.exports =
  # TODO
  new Typedef 'instance-identifier',
    construct: (value) ->
      return unless value?
      unless (typeof value is 'string') and /([^\/^\[]+(?:\[.+\])*)/.test value
        throw new Error "[#{@tag}] unable to convert #{value} into valid XPATH expression"
      value

