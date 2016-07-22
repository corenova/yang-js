Extension = require '../extension'

module.exports =
  new Extension 'config',
    resolve: -> @tag = (@tag is true or @tag is 'true')
    
    evaluate: (data) ->
      return unless data?
      return data if @tag is true and data not instanceof Function
      
      unless data instanceof Function
        throw @error "cannot set data on read-only element"
        
      func = ->
        v = data.call this
        v = expr.eval v for expr in @schema.elements when expr.kind isnt 'config'
        return v
      func.computed = true
      return func
      
    predicate: (data) -> not data? or @tag is true or data instanceof Function

