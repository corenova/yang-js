Extension  = require '../extension'
Expression = require '../expression'
Element    = require '../element'

module.exports =
  new Extension 'module',
    argument: 'name' # required
    scope:
      anydata:      '0..n'
      anyxml:       '0..n'
      augment:      '0..n'
      choice:       '0..n'
      contact:      '0..1'
      container:    '0..n'
      description:  '0..1'
      deviation:    '0..n'
      extension:    '0..n'
      feature:      '0..n'
      grouping:     '0..n'
      identity:     '0..n'
      import:       '0..n'
      include:      '0..n'
      leaf:         '0..n'
      'leaf-list':  '0..n'
      list:         '0..n'
      namespace:    '0..1'
      notification: '0..n'
      organization: '0..1'
      prefix:       '0..1'
      reference:    '0..1'
      revision:     '0..n'
      rpc:          '0..n'
      typedef:      '0..n'
      uses:         '0..n'
      'yang-version': '0..1'
      
    construct: ->
      if @['yang-version']?.tag is '1.1'
        unless @namespace? and @prefix?
          throw @error "must define 'namespace' and 'prefix' for YANG 1.1 compliance"
      if @extension?.length > 0
        @debug? "found #{@extension.length} new extension(s)"
        
    evaluate: (data={}) ->
      return data unless data instanceof Object
      data = expr.eval data for expr in @expressions
      new Element @tag, data, schema: this
      return data
      
    compose: (data, opts={}) ->
      return unless data instanceof Object
      return if data instanceof Function and Object.keys(data).length is 0

      possibilities = (@lookup 'extension', kind for own kind of @scope)
      matches = []
      # we want to make sure every property is fulfilled
      for own k, v of data
        for expr in possibilities when expr?
          @debug? "checking '#{k}' to see if #{expr.tag}"
          match = expr.compose? v, key: k
          break if match?
        unless match?
          console.log "unable to find match for #{k}"
          console.log v
        return unless match?
        matches.push match

      (new Expression @tag, opts.key, this).extends matches...

