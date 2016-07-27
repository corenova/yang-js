Extension = require '../extension'
Yang      = require '../yang'
Property  = require '../property'

module.exports =
  new Extension 'container',
    argument: 'name'
    data: true
    scope:
      action:       '0..n'
      anydata:      '0..n'
      anyxml:       '0..n'
      choice:       '0..n'
      config:       '0..1'
      container:    '0..n'
      description:  '0..1'
      grouping:     '0..n'
      'if-feature': '0..n'
      leaf:         '0..n'
      'leaf-list':  '0..n'
      list:         '0..n'
      must:         '0..n'
      notification: '0..n'
      presence:     '0..1'
      reference:    '0..1'
      status:       '0..1'
      typedef:      '0..n'
      uses:         '0..n'
      when:         '0..1'
      
    construct: (data={}) ->
      return data unless data instanceof Object
      obj = data[@tag] ? @binding
      obj = expr.eval obj for expr in @elements if obj?
      (new Property @tag, obj, schema: this).update data
      
    predicate: (data) -> not data?[@tag]? or data[@tag] instanceof Object
    
    compose: (data, opts={}) ->
      return unless data?.constructor is Object
      # return unless typeof data is 'object' and Object.keys(data).length > 0
      # return if data instanceof Array
      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      # we want to make sure every property is fulfilled
      for own k, v of data
        for expr in possibilities when expr?
          @debug? "checking '#{k}' to see if #{expr.tag}"
          match = expr.compose? v, key: k
          break if match?
        return unless match?
        matches.push match

      (new Yang @tag, opts.key, this).extends matches...
