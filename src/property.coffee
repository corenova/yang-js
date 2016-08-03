# element - property descriptor
Promise  = require 'promise'
events   = require 'events'
XPath    = require './xpath'

class Property
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (name, value, opts={}) ->
    unless name? and opts instanceof Object
      console.log arguments
      throw new Error "must supply 'name' and 'opts' to create a new Property"

    @[k] = v for own k, v of opts when k in [
      'configurable'
      'enumerable'
      'schema'
      'parent'
    ]
    
    @configurable ?= true
    @enumerable   ?= value?
    @name = name
    @_value = value # private

    # Bind the get/set functions to call with 'this' bound to this
    # Property instance.  This is needed since native Object
    # Getter/Setter calls the get/set function with the Object itself
    # as 'this'
    @set = @set.bind this
    @get = @get.bind this

    if value instanceof Object
      # setup direct property access
      unless value.hasOwnProperty '__'
        Object.defineProperty value, '__', writable: true
      value.__ = this

  update: (obj) ->
    return obj unless obj instanceof Object
    @parent = obj
    # update containing object with this property for reference
    unless obj.hasOwnProperty '__'
      Object.defineProperty obj, '__', writable: true, value: {}
    obj.__[@name] = this

    console.debug? "attach property '#{@name}' and return updated obj"
    console.debug? this
    if obj instanceof Array and @schema?.kind is 'list' and @_value?
      for item, idx in obj when item['@key'] is @_value['@key']
        console.debug? "found matching key in #{idx}"
        obj.splice idx, 1, @_value
        return obj
      obj.push @_value
      obj
    else
      Object.defineProperty obj, @name, this

  set: (val, force=false) -> switch
    when force is true then @_value = val
    when @schema?.eval?
      console.debug? "setting #{@name} with parent: #{@parent?}"
      res = @schema.eval { "#{@name}": val }
      val = res.__[@name]?._value # access bypassing 'getter'
      if @parent? then (new Property @name, val, schema: @schema).update @parent
      else @_value = val
    else @_value = val

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
    when @_value instanceof Function then switch
      when @_value.computed is true then @_value.call this
      when @_value.async is true
        (args...) => new Promise (resolve, reject) =>
          @_value.apply this, [].concat args, resolve, reject
      else @_value.bind this
    when @_value?.constructor is Object
      # clean-up properties unknown to the expression
      for own k of @_value
        desc = (Object.getOwnPropertyDescriptor @_value, k)
        delete @_value[k] if desc.writable
      @_value
    else @_value

  find: (xpath) ->
    xpath = new XPath xpath unless xpath instanceof XPath
    unless @_value instanceof Object
      return switch xpath.tag
        when '/'  then xpath.eval @parent
        when '..' then xpath.xpath?.eval @parent
    xpath.eval @_value

module.exports = Property
