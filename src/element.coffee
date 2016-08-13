# Element - cascading symbolic definition tree

Emitter = (require 'events').EventEmitter

class Element extends Emitter

  @use: ->
    res = [].concat(arguments...)
      .filter (x) -> x?
      .map (elem) =>
        exists = Element::match.call this, elem.kind, elem.tag
        if exists?
          console.warn @error "use: already loaded '#{elem.kind}/#{elem.tag}'"
          return exists
        Element::merge.call this, elem
    return switch 
      when res.length > 1  then res
      when res.length is 1 then res[0]
      else undefined

  @error: (msg, ctx=this) ->
    res = new Error msg
    res.name = 'ElementError'
    res.context = ctx
    return res

  constructor: (kind, tag, attrs={}) ->
    unless kind?
      throw @error "must supply 'kind' to create a new Element"
    unless typeof attrs is 'object'
      throw @error "must supply 'attrs' as an object"

    Object.defineProperties this,
      kind:    value: kind, enumerable: true
      tag:     value: tag,  enumerable: true, writable: true
      
      node:    value: (attrs.node is true)
      scope:   value: attrs.scope,  writable: true
      parent:  value: attrs.parent, writable: true

      _events: writable: true # hide event listeners

      # auto-computed properties
      trail:
        get: (->
          node = this
          trail = ((node.tag ? node.kind) while (node = node.parent) and node instanceof Element)
          trail = trail.reverse().join '/'
          return "#{trail}/#{@kind}"
        ).bind this
      root:
        get: (->
          if @parent instanceof Element then @parent.root else this
        ).bind this
      elements:
        get: (->
          (v for own k, v of this when k isnt 'tag').reduce ((a,b) -> switch
            when b instanceof Element then a.concat b
            when b instanceof Array
              a.concat b.filter (x) -> x instanceof Element
            else a
          ), []
        ).bind this
      nodes: get: (-> @elements.filter (x) -> x.node is true  ).bind this
      attrs: get: (-> @elements.filter (x) -> x.node is false ).bind this
      '*':   get: (-> @nodes  ).bind this
      '..':  get: (-> @parent ).bind this
      
  clone: -> (new @constructor @kind, @tag, this).extends @elements.map (x) -> x.clone()

  # primary mechanism for defining sub-elements to become part of the schema
  extends: ->
    elems = ([].concat arguments...).filter (x) -> x? and !!x
    return this unless elems.length > 0
    elems.forEach (expr) => @merge expr
    @emit 'change', elems...
    return this

  # merges an Element into current Element
  merge: (elem) ->
    unless elem instanceof Element
      throw @error "cannot merge a non-Element into an Element", elem

    # a merged element becomes a child of this element
    elem.parent ?= this
    
    unless @scope?
      switch
        when not @hasOwnProperty elem.kind then @[elem.kind] = elem
        when @[elem.kind] not instanceof Array
          @[elem.kind] = [ @[elem.kind] ]
          Object.defineProperty @[elem.kind], 'tags', value: []
          @[elem.kind].tags.push elem.tag
        when elem.tag not in @[elem.kind].tags
          @[elem.kind].tags.push elem.tag
          @[elem.kind].push elem
        else
          throw @error "constraint violation for '#{elem.kind} #{elem.tag}' - cannot define more than once"
      return elem

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
        else if elem.kind is 'argument'
          @[elem.kind] = elem
        else
          throw @error "constraint violation for '#{elem.kind}' - cannot define more than once"
      else
        throw @error "unrecognized scope constraint defined for '#{elem.kind}' with #{@scope[elem.kind]}"

    return elem

  # performs conditional merge based on existence
  update: (elem) ->
    unless elem instanceof Element
      throw @error "cannot update a non-Element into an Element", elem

    #@debug? "update with #{elem.kind}/#{elem.tag}"
    exists = Element::match.call this, elem.kind, elem.tag
    return @merge elem unless exists?

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
    res ?= switch
      when @parent? then Element::lookup.apply @parent, arguments
      else Element::match.call @constructor, kind, tag
    return res

  # Looks for matching Elements using YPATH notation
  # Direction: down the hierarchy (away from root)
  locate: (ypath) ->
    return unless typeof ypath is 'string' and !!ypath
    @debug? "locate: #{ypath}"
    ypath = ypath.replace /\s/g, ''
    if (/^\//.test ypath) and this isnt @root
      return @root.locate ypath
    [ key, rest... ] = ypath.split('/').filter (e) -> !!e
    return this unless key?
    
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

  error: @error
  debug: if console.debug? then (msg) -> switch typeof msg
    when 'object' then console.debug msg
    else console.debug "[#{@trail}] #{msg}"

  # converts to a simple JS object
  toObject: ->
    @debug? "converting #{@kind} toObject with #{@elements.length}"
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
      when @tag instanceof Object then "#{@tag}"
      else @tag

module.exports = Element
