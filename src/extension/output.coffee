Extension = require '../extension'

module.exports =
  new Extension 'output',
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
        func.apply this, [
          input,
          (res) =>
            # validate output prior to calling 'resolve'
            try res = expr.eval res for expr in @schema.output.elements
            catch e then reject e
            resolve res
          reject
        ]

