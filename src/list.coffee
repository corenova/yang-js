debug = require('debug')('yang:list')
delegate = require 'delegates'

Container = require './container'
Property = require './property'
XPath = require './xpath'
kProp = Symbol.for('property')

class ListItem extends Container

  @property 'key',
    get: -> @content?['@key'] or @state.key

  @property 'keys',
    get: -> if @schema.key then @schema.key.tag else []

  @property 'path',
    get: ->
      entity = ".['#{@key}']"
      unless @parent?
        return XPath.parse entity, @schema
      @state.path ?= @parent.path.clone().append entity
      return @state.path 

  @property 'uri',
    get: -> @parent?.uri ? @name

  constructor: (schema, data) ->
    super schema.datakey, schema
    # only apply attr schemas (in order to determine 'key')
    data = attr.eval data, @context for attr in schema.attrs when data?
    @state.value = data
    @state.key = data?['@key']

  debug: -> debug @uri, arguments...

  find: (pattern) -> switch
    # here we skip a level of hierarchy
    when /^\.\.\//.test(pattern) and @parent?
      @parent.find arguments...
    else super

  join: (obj, ctx={}) ->
    { property: parent, state: opts } = ctx
    { suppress, force } = opts
    unless parent instanceof List
      throw @error "can only join List instance"
      
    @container = parent.container
    @parent = parent
    
    value = @state.value
    @state.value = undefined
    parent.update (@set value, { suppress, force }), opts
    @state.attached = true
    return this
      
  remove: (opts={}) ->
    { suppress, inner, actor } = opts
    @state.prev = @state.value
    @state.value = null
    @emit 'update', this, actor unless suppress or inner
    @emit 'change', this, actor unless suppress
    @parent.remove this, opts
    
  inspect: ->
    res = super
    res.key = @key
    res.keys = @keys
    return res

class List extends Property
  debug: -> debug @uri, arguments...

  constructor: ->
    super
    @state.changes = new Map # list changes are tracked in a map

  @property 'changed',
    get: -> @state.changes.size

  @property 'change',
    get: -> Array.from(@state.changes.keys()).map (i) ->
      obj = i.change
      obj[k] = i.get(k) for k in i.keys
      obj

  @property 'children',
    get: ->
      return if @state.value? then Array.from(@state.value.values()) else []

  update: (item, opts={}) -> switch
    when @schema.key? and @state.value.has(item.key)
      unless opts.replace
        throw @error "cannot update due to key conflict: #{item.key}"
      exists = @state.value.get(item.key)
      exists.merge item.content, opts
      @state.changes.set(exists) if exists.changed
    when @schema.key?
      @state.value.set(item.key, item)
      @state.changes.set(item, true)
    else
      @state.value.add(item)
      @state.changes.set(item, true)

  remove: (item, opts={}) ->
    { suppress, inner, actor } = opts
    switch
      when not item? then return super opts
      when @schema.key? then @state.value.delete(item.key)
      else @state.value.delete(item)
    @emit 'update', this, actor unless suppress or inner
    @emit 'change', this, actor unless suppress
    return this

  merge: (value, opts={}) ->
    return @set value, opts unless @content?
    value = [].concat(value).filter(Boolean)
    value = switch
      when @schema? then @schema.apply value, this
      else value
    value.forEach (item) =>
      if item.key in @content
        exists = @content[item.key]
        exists[k] = v for own k, v of item
      else
        @content.push item
    return this

  set: (value, opts={}) ->
    { force = false, suppress = false, replace = true, inner = false, actor } = opts
    @clean()
    @debug "[list:set] enter with:"
    @debug value
    @state.prev = @content
    
    return @remove null, opts if value is null
    unless @mutable or force
      throw @error "cannot set data on read-only (config false) element"

    value = [].concat(value).filter(Boolean)
    @state.value = @schema.apply value, this
    @state.enumerable = @state.value.length
    
    try Object.defineProperty @container, @name,
      configurable: true
      enumerable: @state.enumerable

    if @changed
      @emit 'update', this, actor unless suppress or inner
      @emit 'change', this, actor unless suppress
      @emit 'create', this, actor unless suppress or replace
    return this
    
  create: (value, opts={}) ->
    opts.replace = false;
    @merge value, opts

  toJSON: (tag=false) ->
    props = @children
    value = props.map (item) -> item.toJSON()
    value = "#{@name}": value if tag
    return value

module.exports = List
