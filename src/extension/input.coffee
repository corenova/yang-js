Extension  = require '../extension'

module.exports =
  new Extension 'input',
    scope:
      anyxml:      '0..n'
      choice:      '0..n'
      container:   '0..n'
      grouping:    '0..n'
      leaf:        '0..n'
      'leaf-list': '0..n'
      list:        '0..n'
      typedef:     '0..n'
      uses:        '0..n'
      
    evaluate: (func) ->
      unless func instanceof Function
        # should try to dynamically compile 'string' into a Function
        throw @error "expected a function but got a '#{typeof func}'"
      return (input, resolve, reject) ->
        # validate input prior to calling 'func'
        try input = expr.eval input for expr in @schema.input.expressions
        catch e then reject e
        func.call this, input, resolve, reject

