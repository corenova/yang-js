Extension  = require '../extension'
Expression = require '../expression'
Element    = require '../element'

module.exports =
  new Extension 'rpc',
    scope:
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      input:        '0..1'
      output:       '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
      
    evaluate: (data={}) ->
      return data unless data instanceof Object
      rpc = data[@tag] ? @bindings[0] ? (a,b,c) => throw @error "handler function undefined"
      unless rpc instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      unless rpc.length is 3
        throw @error "cannot define without function (input, resolve, reject)"
      rpc = expr.eval rpc for expr in @expressions
      func = (args..., resolve, reject) ->
        # rpc expects only ONE argument
        rpc.apply this, [
          args[0],
          (res) -> resolve res
          (err) -> reject err
        ]
      func.async = true
      (new Element @tag, func, schema: this).update data
      
    compose: (data, opts={}) ->
      return unless data instanceof Function
      return unless Object.keys(data).length is 0
      return unless Object.keys(data.prototype).length is 0

      # TODO: should inspect function body and infer 'input'
      (new Expression @tag, opts.key, this).bind data

