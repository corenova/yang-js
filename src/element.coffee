# element - property descriptor
promise  = require 'promise'
events   = require 'events'
path     = require 'path'
operator = require './operator'

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
      'static'
    ]
    
    @configurable ?= true
    @enumerable   ?= value?
    @name = name
    @_value = value # private

    # Bind the get/set functions to call its prototype methods bound
    # to this Element instance.  This is needed since native Object
    # Getter/Setter calls the prototype function with the object
    # itself as 'this'
    @set = (-> Element::set.apply this, arguments).bind this
    @get = (-> Element::get.apply this, arguments).bind this

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
    when arguments.length then @find arguments...
    # when value is a function, we will call it with the current
    # 'property' object as the bound context (this) for the
    # function being called.
    when @_value instanceof Function then switch
      when @_value.computed is true then @_value.call this
      when @_value.async is true
        (args...) => new promise (resolve, reject) =>
          @_value.apply this, [].concat args, resolve, reject
      else @_value.bind this
    when @_value?.constructor is Object and @static isnt true
      # clean-up properties unknown to the expression
      for own k, v of @_value 
        desc = (Object.getOwnPropertyDescriptor @_value, k)
        delete @_value[k] if desc.writable
      @_value
    else @_value

  find: (xpath) ->
    return unless typeof xpath is 'string'
    xpath = path.normalize xpath
    # establish starting 'res'
    res = switch
      when /^\//.test xpath
        res = @parent
        res = res.__.parent while res?.__?.parent?
        res
      when /^\.\.\//.test xpath
        xpath = xpath.replace /^\.\.\//, ''
        @parent
      else
        res = @_value
    exprs = (xpath.match /([^\/^\[]+(?:\[.+\])*)/g) ? []
    for expr in exprs when !!expr
      break unless res?
      break if res instanceof Array and res.length is 0

      expr = /([^\[]+)(?:\[\s*(.+?)\s*\])*/.exec expr
      break unless expr?

      target = expr[1]
      predicate = expr[2]

      # TODO handle prefix (but ignore for now)
      [ prefix..., target ] = target.split ':'
      
      console.debug? "target node is: #{target}"
      res = switch 
        when target is '..' then res.__?.parent
        when target is '.' then res
        when res instanceof Array
          # we use 'reduce' here since 'match' can be multiplicative
          matches = res.reduce ((a,b) -> switch
            when b instanceof Array then a.concat (b.map (x) -> x[target])...
            else a.concat b[target]
          ), []
          Object.defineProperty matches, '__', res.__
        else res[target]

      if res? and predicate?
        matches = [ res ] unless res instanceof Array
        matches = res.filter (node) -> switch
          when (Number) predicate then node[(Number predicate)]?
          else
            try
              op = operator.parse predicate
              # TODO: expand support for XPATH predicates
              op.evaluate op.variables().reduce ((a,b) ->
                a[b] = switch b
                  when 'key'     then -> node['@key']
                  when 'current' then -> node
                  else node[b]
                return a
              ), {}
            catch then false
        res = Object.defineProperty matches, '__', res.__
              
    if res instanceof Array
      switch
        when res.length > 1 then res
        when res.length is 1 then res[0]
        else undefined
    else res

module.exports = Element
