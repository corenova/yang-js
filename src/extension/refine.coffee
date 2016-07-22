Extension = require '../extension'

module.exports =
  new Extension 'refine',
    scope:
      default:        '0..1'
      description:    '0..1'
      reference:      '0..1'
      config:         '0..1'
      mandatory:      '0..1'
      presence:       '0..1'
      must:           '0..n'
      'min-elements': '0..1'
      'max-elements': '0..1'
      units:          '0..1'

    resolve: ->
      target = @parent.grouping.locate @tag
      unless target?
        console.warn @error "unable to locate '#{@tag}'"
        return

      # TODO: revisit this logic, may need to 'merge' the new expr into existing expr
      @elements.forEach (expr) -> switch
        when target.hasOwnProperty expr.kind
          if expr.kind in [ 'must', 'if-feature' ] then target.extends expr
          else target[expr.kind] = expr
        else target.extends expr
