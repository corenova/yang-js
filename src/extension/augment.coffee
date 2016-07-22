Extension = require '../extension'

module.exports =
  new Extension 'augment',
    scope:
      action:        '0..n'
      anydata:       '0..n'
      anyxml:        '0..n'
      case:          '0..n'
      choice:        '0..n'
      container:     '0..n'
      description:   '0..1'
      'if-feature':  '0..n'
      leaf:          '0..n'
      'leaf-list':   '0..n'
      list:          '0..n'
      notification:  '0..n'
      reference:     '0..1'
      status:        '0..1'
      uses:          '0..n'
      when:          '0..1'

    resolve: ->
      target = switch @parent.kind
        when 'module'
          unless /^\//.test @tag
            throw @error "'#{@tag}' must be absolute-schema-path"
          @locate @tag
        when 'uses'
          if /^\//.test @tag
            throw @error "'#{@tag}' must be relative-schema-path"
          @parent.grouping.locate @tag

      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return

      unless @when?
        @debug? "augmenting '#{target.kind}:#{target.tag}'"
        target.extends @elements.filter (x) ->
          x.kind not in [ 'description', 'reference', 'status' ]
      else
        target.on 'eval', (data) =>
          data = expr.eval data for expr in @elements if data?
