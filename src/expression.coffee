# expression - evaluable Element

Element = require './element'

class Expression extends Element

  eval: (data, opts={}) ->
    opts.adaptive ?= true
    data = @evaluate data
    unless @predicate data
      throw @error "predicate validation error during eval", data
    if opts.adaptive
      @once 'changed', arguments.callee.bind(this, data)
    @emit 'eval', data
    return data

module.exports = Expression
