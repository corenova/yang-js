Typedef = require '../typedef'

module.exports =
  new Typedef 'empty',
    construct: (value) ->
      if value?
        throw new Error "[#{@tag}] cannot contain value"
      null
