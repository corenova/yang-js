debug = require('debug')('yang:list') if process.env.DEBUG?
delegate = require 'delegates'

Container = require './container'
Property = require './property'
XPath = require './xpath'
kProp = Symbol.for('property')

class ListItem extends Container

  @property 'key',
    get: -> @content?['@key']

  @property 'path',
    get: ->
      entity = ".['#{@key}']"
      unless @parent?
        return XPath.parse entity, @schema
      @state.path ?= @parent.path.clone().append entity
      return @state.path 

  constructor: (schema, data) ->
    super schema.datakey, schema
    # only apply attr schemas (in order to determine 'key'
    data = attr.eval data, @context for attr in schema.attrs when data?
    @state.value = data

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
      
  remove: (opts) -> @parent.remove this, opts

  inspect: ->
    res = super
    res.key = @key
    return res

class List extends Property

  @Item = ListItem
  
  @property 'content',
    get: ->
      value = Array.from(@state.value.values()).map (li) -> li.content
      Object.defineProperty value, kProp, enumerable: false, value: this
      Object.defineProperty value, '$', enumerable: false, value: @get.bind(this)
      return value
    set: (value) -> @set value, { force: true, suppress: true }

  @property 'children',
    get: ->
      return if @state.value? then Array.from(@state.value.values()) else []

  constructor: ->
    super
    @state.value = switch
      when @schema.key? then new Map
      else new Set

  update: (item, opts={}) -> switch
    when @schema.key? and @state.value.has(item.key)
      unless opts.merge
        throw @error "cannot update due to key conflict: #{item.key}"
      exists = @state.value.get(item.key)
      exists.merge item.content, opts
    when @schema.key? then @state.value.set(item.key, item)
    else @state.value.add(item)

  remove: (item, opts={}) ->
    switch
      when not item? then return super opts
      when @schema.key?
        @state.value.delete(item.key)
      else @state.value.delete(item)
    @emit 'update', this unless opts.suppress
    @emit 'delete', item unless opts.suppress
    return this

  set: (value, opts={}) ->
    { force=false, replace=true, suppress=false } = opts
    @debug "[set] enter with:"
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

    @emit 'update', this unless suppress
    return this
    
  create: (value) ->
    @merge value, replace: false
    
module.exports = List
