# element - property descriptor
Promise  = require 'promise'
events   = require 'events'
XPath    = require './xpath'

class Element
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

  constructor: (name, value, opts={}) ->
    unless name? and opts instanceof Object
      throw @error "must supply 'name' and 'opts' to create a new Element"

    @[k] = v for own k, v of opts when k in [
      'configurable'
      'enumerable'
      'expr'
      'parent'
    ]
    
    @configurable ?= true
    @enumerable   ?= value?
    @name = name
    @_value = value # private

    # Bind the get/set functions to call with 'this' bound to this
    # Element instance.  This is needed since native Object
    # Getter/Setter calls the get/set function with the Object itself
    # as 'this'
    @set = @set.bind this
    @get = @get.bind this

    if value instanceof Object
      # setup direct property access
      unless value.hasOwnProperty '__'
        Object.defineProperty value, '__', writable: true
      value.__ = this

  set: (val, force=false) -> switch
    when force is true then @_value = val
    when @expr?.eval?
      console.debug? "setting #{@name} with parent: #{@parent?}"
      res = @expr.eval { "#{@name}": val }
      val = res.__[@name]?._value # access bypassing 'getter'
      if @parent? then @expr.update @parent, @name, val
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

module.exports = Element
