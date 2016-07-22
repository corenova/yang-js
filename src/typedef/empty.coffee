Typedef = require '../typedef'

module.exports =
  new Typedef 'empty',
    evaluate: (value) ->
      if value?
        throw new Error "[#{@tag}] cannot contain value"
      null
