Extension = require '../extension'
Property  = require '../property'

module.exports =
  new Extension 'key',
    resolve: ->
      @tag = @tag.split ' '
      unless (@tag.every (k) => @parent.match('leaf', k)?)
        throw @error "referenced key items do not have leaf elements"
          
    evaluate: (data) ->
      return data unless data instanceof Array
      exists = {}
      for item in data when item instanceof Object
        key = (@tag.map (k) -> item[k]).join ','
        if exists[key] is true
          throw @error "key conflict for #{key}"
        exists[key] = true
        (new Property '@key', key, schema: this, enumerable: false).update item
        
        @debug? "defining a direct key mapping for '#{key}'"
        key = "__#{key}__" if (Number) key
        
        (new Property key, item, schema: this, enumerable: false).update data
      return data
      
    predicate: (data) ->
      return true if data instanceof Array
      @tag.every (k) => data[k]?

