Extension  = require '../extension'
Expression = require '../expression'
Element    = require '../element'

module.exports =
  new Extension 'leaf-list',
    scope:
      config: '0..1'
      description: '0..1'
      'if-feature': '0..n'
      'max-elements': '0..1'
      'min-elements': '0..1'
      must: '0..n'
      'ordered-by': '0..1'
      reference: '0..1'
      status: '0..1'
      type: '0..1'
      units: '0..1'
      when: '0..1'
      
    evaluate: (data={}) ->
      return data unless data instanceof Object
      ll = data[@tag] ? @bindings[0]
      ll = expr.eval ll for expr in @expressions if ll?
      (new Element @tag, ll, schema: this).update data
      
    predicate: (data) -> not data[@tag]? or data[@tag] instanceof Array
    
    compose: (data, opts={}) ->
      return unless data instanceof Array
      return unless data.every (x) -> typeof x isnt 'object'
      type_ = @lookup 'extension', 'type'
      types = data.map (x) -> type_.compose? x
      # TODO: form a type union if more than one types
      (new Expression @tag, opts.key, this).extends types[0]

