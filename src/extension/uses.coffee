Extension  = require '../extension'

module.exports =
  new Extension 'uses',
    scope:
      augment:      '0..n'
      description:  '0..1'
      'if-feature': '0..n'
      refine:       '0..n'
      reference:    '0..1'
      status:       '0..1'
      when:         '0..1'
      
    resolve: ->
      grouping = @lookup 'grouping', @tag
      unless grouping?
        throw @error "unable to resolve #{@tag} grouping definition"

      # setup change linkage to upstream definition
      #grouping.on 'changed', => @emit 'changed'
      @grouping = grouping.clone()
      unless @when?
        @debug? "extending #{@grouping} into #{@parent}"
        @parent.extends @grouping.expressions.filter (x) ->
          x.kind not in [ 'description', 'reference', 'status' ]
      else
        @parent.on 'eval', (data) =>
          data = expr.eval data for expr in @grouping.expressions if data?
