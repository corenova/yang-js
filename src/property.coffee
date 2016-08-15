# element - property descriptor
Promise  = require 'promise'
events   = require 'events'
XPath    = require './xpath'
Emitter  = require './emitter'

class Property extends Emitter
  
  constructor: (name, value, opts={}) ->
    unless name? and opts instanceof Object
      console.log arguments
      throw new Error "must supply 'name' and 'opts' to create a new Property"

    @name = name
    @configurable  = opts.configurable
    @configurable ?= true
    @enumerable    = opts.enumerable
    @enumerable   ?= value?

    super opts.parent
    
    Object.defineProperties this,
      schema: value: opts.schema
      path:
        get: (->
          x = this
          p = [ @name ]
          while (x = x.parent?.__) and x.schema?.kind isnt 'module'
            if x.schema?.kind is 'list'
              continue unless x.content instanceof Array
            p.unshift x.name 
          return p.join '/'
        ).bind this
      content:
        get: -> value
        set: ((val) ->
          @emit 'update', this if val isnt value
          value = val
        ).bind this

    # Bind the get/set functions to call with 'this' bound to this
    # Property instance.  This is needed since native Object
    # Getter/Setter calls the get/set function with the Object itself
    # as 'this'
    @set = @set.bind this
    @get = @get.bind this

    # setup 'update/create/delete' event propagation up the tree
    @propagate 'update', 'create', 'delete'
    
    if value instanceof Object
      # setup direct property access
      unless value.hasOwnProperty '__'
        Object.defineProperty value, '__', writable: true
      value.__ = this

  join: (obj) ->
    return obj unless obj instanceof Object
    @parent = obj
    
    # update containing object with this property for reference
    unless obj.hasOwnProperty '__props__'
      Object.defineProperty obj, '__props__', value: {}
    prev = obj.__props__[@name]
    obj.__props__[@name] = this

    console.debug? "join property '#{@name}' into obj"
    console.debug? obj
    if obj instanceof Array and @schema?.kind is 'list' and @content?
      for item, idx in obj when item['@key'] is @content['@key']
        console.debug? "found matching key in #{idx}"
        obj.splice idx, 1, @content
        return obj
      obj.push @content
    else
      Object.defineProperty obj, @name, this
    @emit 'update', this
    return obj

  set: (val, force=false) -> switch
    when force is true then @content = val
    when @schema?.apply?
      console.debug? "setting #{@name} with parent: #{@parent?}"
      res = @schema.apply { "#{@name}": val }
      prop = res.__props__[@name]
      if @parent? then prop.join @parent
      else @content = prop.content
    else @content = val

  get: -> switch
    when arguments.length
      match = @find arguments...
      switch
        when match.length is 1 then match[0]
        when match.length > 1  then match
        else undefined
    # when value is a function, we will call it with the current
    # 'property' object as the bound context (this) for the
    # function being called.
    when @content instanceof Function then switch
      when @content.computed is true then @content.call this
      when @content.async is true
        (args...) => new Promise (resolve, reject) =>
          @content.apply this, [].concat args, resolve, reject
      else @content.bind this
    when @content?.constructor is Object
      # clean-up properties unknown to the expression
      for own k of @content
        desc = (Object.getOwnPropertyDescriptor @content, k)
        delete @content[k] if desc.writable
      @content
    else @content

  find: (xpath) ->
    xpath = new XPath xpath unless xpath instanceof XPath
    unless @content instanceof Object
      return switch xpath.tag
        when '/'  then xpath.apply @parent
        when '..' then xpath.xpath?.apply @parent
    xpath.apply @content

module.exports = Property
