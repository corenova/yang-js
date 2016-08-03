Extension = require '../extension'
Property  = require '../property'

module.exports =
  new Extension 'key',
    argument: 'value'
    resolve: ->
      @tag = @tag.split ' '
      unless (@tag.every (k) => @parent.match('leaf', k)?)
        throw @error "referenced key items do not have leaf elements"
          
    construct: (data) ->
      return data unless data instanceof Object
      list = data
      list = [ list ] unless list instanceof Array
      exists = {}
      for item in list when item instanceof Object
        unless item.hasOwnProperty '@key'
          Object.defineProperty item, '@key',
            get: (->
              @debug? "GETTING @key from #{this} using #{@tag}:"
              (@tag.map (k) -> item[k]).join ','
            ).bind this
        key = item['@key']
        if exists[key] is true
          throw @error "key conflict for #{key}"
        exists[key] = true
          
        #(new Element '@key', key, schema: this, enumerable: false).update item

        if data instanceof Array
          @debug? "defining a direct key mapping for '#{key}'"
          key = "__#{key}__" if (Number) key
          (new Property key, item, schema: this, enumerable: false).update data
      return data
      
    predicate: (data) ->
      return true if data instanceof Array
      @tag.every (k) => data[k]?

