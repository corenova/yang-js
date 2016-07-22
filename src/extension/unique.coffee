Extension  = require '../extension'

module.exports =
  new Extension 'unique',
    resolve: ->
      @tag = @tag.split ' '
      unless (@tag.every (k) => @parent.match('leaf', k)?)
        throw @error "referenced unique items do not have leaf elements"
        
    predicate: (data) ->
      return true unless data instanceof Array
      seen = {}
      data.every (item) =>
        key = @tag.reduce ((a,b) -> a += item[b] ), ''
        return false if seen[key]
        seen[key] = true
        return true
    
