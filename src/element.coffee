# Element - cascading symbolic definition tree

events = require 'events'

events.EventEmitter.defaultMaxListeners = 20

class Element
  # mixin the EventEmitter
  @::[k] = v for k, v of events.EventEmitter.prototype

<<<<<<< HEAD
  constructor: (kind, tag, attrs={}) ->
    unless kind?
      throw @error "must supply 'kind' to create a new Element"
    unless typeof attrs is 'object'
      throw @error "must supply 'attrs' as an object"
      
    Object.defineProperties this,
      kind:    value: kind, enumerable: true
      tag:     value: tag,  enumerable: true, writable: true
      data:    value: attrs.data
      
      parent:  value: attrs.parent,  writable: true
      scope:   value: attrs.scope,   writable: true

      # auto-computed properties
      root:
        get: (->
          if @parent instanceof Element then @parent.root else this
        ).bind this
      elements:
        get: (->
          (v for own k, v of this).reduce ((a,b) -> switch
            when b instanceof Element then a.concat b
            when b instanceof Array
              a.concat b.filter (x) -> x instanceof Element
            else a
          ), []
        ).bind this
        
      '*':  get: (-> @elements.filter (x) -> x.data is true ).bind this
      '..': get: (-> @parent   ).bind this
      
      _events: writable: true # make this invisible

  clone: -> (new Element @kind, @tag, this).extends @elements.map (x) -> x.clone()

  # primary mechanism for defining sub-elements to become part of the schema
  extends: (elems...) ->
    elems = ([].concat elems...).filter (x) -> x? and !!x
    return this unless elems.length > 0
    elems.forEach (expr) => @merge expr
    @emit 'changed', elems
    return this

  # merges an Element into current Element
  merge: (elem) ->
    unless elem instanceof Element
      throw @error "cannot merge a non-Element into an Element", elem

    unless @scope?
      @[elem.kind] = elem
    else
      unless elem.kind of @scope
        if elem.scope?
          @debug? @scope
          throw @error "scope violation - invalid '#{elem.kind}' extension found"
        else
          @scope[elem.kind] = '*' # this is hackish...

      switch @scope[elem.kind]
        when '0..n', '1..n', '*'
          unless @hasOwnProperty elem.kind
            Object.defineProperty this, elem.kind,
              enumerable: true
              value: []
            Object.defineProperty @[elem.kind], 'tags',
              value: []
          unless elem.tag in @[elem.kind].tags
            @[elem.kind].tags.push elem.tag
            @[elem.kind].push elem
          else
            throw @error "constraint violation for '#{elem.kind} #{elem.tag}' - cannot define more than once"
        when '0..1', '1'
          unless @hasOwnProperty elem.kind
            Object.defineProperty this, elem.kind,
              enumerable: true
              value: elem
          # else if elem.kind is 'argument'
          #   @[elem.kind] = elem
          else
            throw @error "constraint violation for '#{elem.kind}' - cannot define more than once"
        else
          throw @error "unrecognized scope constraint defined for '#{elem.kind}' with #{@scope[elem.kind]}"

    # a merged element becomes a child of this element
    elem.parent = this
    return elem

  # performs conditional merge based on existence
  update: (elem) ->
    unless elem instanceof Element
      throw @error "cannot update a non-Element into an Element", elem

    #@debug? "update with #{elem.kind}/#{elem.tag}"
    exists = @match elem.kind, elem.tag
    return @merge elem unless exists?
=======
  constructor: (name, value, opts={}) ->
    unless name? and opts instanceof Object
      throw new Error "must supply 'name' and 'opts' to create a new Element"
>>>>>>> master

    #@debug? "update #{exists.kind} in-place for #{elem.elements.length} elements"
    exists.update target for target in elem.elements
    return exists

  # Looks for matching Elements using kind and tag
  # Direction: up the hierarchy (towards root)
  lookup: (kind, tag) ->
    res = switch
      when this not instanceof Object then undefined
      when this instanceof Element then @match kind, tag
      else Element::match.call this, kind, tag
    res ?= Element::lookup.apply @parent, arguments if @parent?
    return res

  # Looks for matching Elements using YPATH notation
  # Direction: down the hierarchy (away from root)
  locate: (ypath) ->
    return unless typeof ypath is 'string' and !!ypath
    ypath = ypath.replace /\s/g, ''
    if (/^\//.test ypath) and this isnt @root
      return @root.locate ypath
    [ key, rest... ] = ypath.split('/').filter (e) -> !!e
    return this unless key?
    
<<<<<<< HEAD
    @debug? "locate #{key} with '#{rest}'"

    # TODO: should consider a different semantic element to match
    # explicit 'kind'
    switch
      when key is '..' then kind = key
      when /^{.*}$/.test(key)
        kind = 'grouping'
        tag  = key.replace /^{(.*)}$/, '$1'
      when /^\[.*\]$/.test(key)
        key = key.replace /^\[(.*)\]$/, '$1'
        [ kind..., tag ]  = key.split ':'
        [ tag, selector ] = tag.split '='
        kind = kind[0] if kind?.length
      else
        [ tag, selector ] = key.split '='
        kind = '*'

    match = @match kind, tag
    return switch
      when rest.length is 0 then match
      else match?.locate rest.join('/')
      
  # Looks for a matching Element in immediate sub-elements
  match: (kind, tag) ->
    return unless this instanceof Object # do we need this?
    return unless kind? and @hasOwnProperty kind
    return @[kind] unless tag?

    match = @[kind]
    match = [ match ] unless match instanceof Array
    for elem in match when elem instanceof Element
      key = if elem.tag? then elem.tag else elem.kind
      return elem if tag is key
    return undefined

  error: (msg, context=this) ->
    res = new Error msg
    res.name = "ElementError"
    res.context = context
    return res

  debug: if console.debug? then (msg) -> console.debug "[#{@kind}/#{@tag}] #{msg}"

  # converts to a simple JS object
  toObject: ->
    @debug "converting #{@kind} toObject with #{@elements.length}"
    sub =
      @elements
        .filter (x) => x.parent is this
        .reduce ((a,b) ->
          for k, v of b.toObject()
            if a[k] instanceof Object
              a[k][kk] = vv for kk, vv of v if v instanceof Object
            else
              a[k] = v
          return a
        ), {}

    return "#{@kind}": switch
      when Object.keys(sub).length > 0
        if @tag? then "#{@tag}": sub else sub
      else @tag
=======
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
      if @parent? then (new Element @name, val, schema: @schema).update @parent
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
>>>>>>> master

module.exports = Element
