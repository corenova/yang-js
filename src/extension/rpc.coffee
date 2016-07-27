Extension = require '../extension'
Yang      = require '../yang'
Property  = require '../property'

module.exports =
  new Extension 'rpc',
    argument: 'name'
    data: true
    scope:
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      input:        '0..1'
      output:       '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
      
    construct: (data={}) ->
      return data unless data instanceof Object
      rpc = data[@tag] ? @binding ? (a,b,c) => throw @error "handler function undefined"
      unless rpc instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      unless rpc.length is 3
        throw @error "cannot define without function (input, resolve, reject)"
      rpc = expr.eval rpc for expr in @elements
      rpc.async = true
      (new Property @tag, rpc, schema: this).update data
      
    compose: (data, opts={}) ->
      return unless data instanceof Function
      return unless Object.keys(data).length is 0
      return unless Object.keys(data.prototype).length is 0

      # TODO: should inspect function body and infer 'input'
      (new Yang @tag, opts.key, this).bind data

