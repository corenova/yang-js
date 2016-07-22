Extension  = require '../extension'
Expression = require '../expression'
Element    = require '../element'

module.exports =
  new Extension 'leaf',
    scope:
      config:       '0..1'
      default:      '0..1'
      description:  '0..1'
      'if-feature': '0..n'
      mandatory:    '0..1'
      must:         '0..n'
      reference:    '0..1'
      status:       '0..1'
      type:         '0..1'
      units:        '0..1'
      when:         '0..1'
      
    resolve: -> 
      if @mandatory?.tag is true and @default?
        throw @error "cannot define 'default' when 'mandatory' is true"
        
    evaluate: (data={}) ->
      return data unless data?.constructor is Object
      val = data[@tag] ? @bindings[0]
      console.debug? "expr on leaf #{@tag} for #{val} with #{@expressions.length} exprs"
      val = expr.eval val for expr in @expressions
      (new Element @tag, val, schema: this).update data
      
    compose: (data, opts={}) ->
      return if data instanceof Array
      return if data instanceof Object and Object.keys(data).length > 0
      type = (@lookup 'extension', 'type')?.compose? data
      return unless type?
      @debug? "leaf #{opts.key} found #{type?.tag}"
      (new Expression @tag, opts.key, this).extends type

