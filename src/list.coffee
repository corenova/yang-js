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

  get: (pattern) -> switch
    when pattern? then super
    else @content

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

  @Item = ListItem
  
  constructor: ->
    super
    @state.value = switch
      when @schema.key? then new Map
      else new Set

  @property 'content',
    get: ->
      value = Array.from(@state.value.values()).map (li) -> li.content
      Object.defineProperty value, kProp, enumerable: false, value: this
      Object.defineProperty value, '$', enumerable: false, value: @in.bind(this)
      return value
    set: (value) -> @set value, { force: true, suppress: true }

  @property 'changed',
    get: -> @state.changes.size

  @property 'change',
    get: -> Array.from(@state.changes).map (i) ->
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
      @state.changes.add(exists) if exists.changed
    when @schema.key?
      @state.value.set(item.key, item)
      @state.changes.add(item)
    else
      @state.value.add(item)
      @state.changes.add(item)

  remove: (item, opts={}) ->
    { suppress, inner, actor } = opts
    switch
      when not item? then return super opts
      when @schema.key? then @state.value.delete(item.key)
      else @state.value.delete(item)
    @emit 'update', this, actor unless suppress or inner
    @emit 'change', this, actor unless suppress
    return this

  set: (value, opts={}) ->
    { force = false, replace = true, suppress = false, inner = false, create = false, actor } = opts
    @clean()
    @debug "[list:set] enter with:"
    @debug value
    @state.prev = @content
    @state.value.clear() unless opts.merge is true

    return @remove null, opts if value is null

    unless @mutable or force
      throw @error "cannot set data on read-only (config false) element"

    ctx = @context.with(opts).with(suppress:true)
    value = [].concat(value).filter(Boolean)
    value = switch
      when not @mutable
        @schema.validate value, ctx
      when @schema.apply?
        @schema.apply value, ctx
      else value
        
    @state.enumerable = @state.value.size
    
    try Object.defineProperty @container, @name,
      configurable: true
      enumerable: @state.enumerable

    if @changed
      @emit 'update', this, actor unless suppress or inner
      @emit 'change', this, actor unless suppress

    value = value[0] if create and value.length == 1
    return if create then value else this
    
  create: (value, opts={}) ->
    { suppress=false } = opts
    opts.replace = false
    opts.create = true
    value = @merge value, opts
    @emit 'create', value unless suppress
    return value

  toJSON: (tag=false) ->
    props = @children
    value = props.map (item) -> item.toJSON()
    value = "#{@name}": value if tag
    return value
module.exports = List
