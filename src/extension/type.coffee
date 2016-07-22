Extension  = require '../extension'
Expression = require '../expression'

module.exports =
  new Extension 'type',
    scope:
      base:               '0..1'
      bit:                '0..n'
      enum:               '0..n'
      'fraction-digits':  '0..1'
      length:             '0..1'
      path:               '0..1'
      pattern:            '0..n'
      range:              '0..1'
      'require-instance': '0..1'
      type:               '0..n' # for 'union' case only
      
    resolve: ->
      typedef = @lookup 'typedef', @tag
      unless typedef?
        throw @error "unable to resolve typedef for #{@tag}"
        
      @convert = typedef.convert?.bind null, this
      
      unless @parent.root or @parent.kind is 'type'
        try @parent.extends typedef.default, typedef.units
          
    evaluate: (data) -> switch
      when data instanceof Function then data
      when data instanceof Array then data.map (x) => @convert x
      else @convert data
        
    compose: (data, opts={}) ->
      return if data instanceof Function
      #return if data instanceof Object and Object.keys(data).length > 0
      typedefs = @lookup 'typedef'
      for typedef in typedefs
        @debug? "checking if '#{data}' is #{typedef.tag}"
        try break if (typedef.construct data) isnt undefined
        catch e then @debug? e
      return unless typedef? # shouldn't happen since almost everything is 'string'
      (new Expression @tag, typedef.tag)

