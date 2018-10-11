debug = require('debug')('yang:list') if process.env.DEBUG?
delegate = require 'delegates'

Container = require './container'
Property = require './property'
kProp = Symbol.for('property')

class ListItem extends Container

  @property 'key',
    get: -> @content?['@key']

  @property 'path',
    get: ->
      entity = "#{@name}['#{@key}']"
      return entity unless @parent?
      @state.path ?= @parent.path.clone().append entity
      return @state.path 

  constructor: (schema, data) ->
    super schema.datakey, schema
    # only apply attr schemas (in order to determine 'key'
    data = attr.eval data, @context for attr in schema.attrs when data?
    @state.value = data

  delegate @prototype, 'state'
    .access 'list'

  get: (pattern) -> switch
    when pattern? then super
    else @content

  join: (@list, opts) ->
    @container = @list.container
    value = @state.value
    @state.value = undefined
    @list.update (@set value, { suppress: true }), opts
    return this
      
  remove: -> @list.remove this

  inspect: ->
    res = super
    res.key = @key
    return res

class List extends Property

  @Item = ListItem
  
  @property 'content',
    get: ->
      value = Array.from(@state.value.values()).map (li) -> li.content
      Object.defineProperty value, kProp, value: this
      Object.defineProperty value, '$', value: @get.bind(this)
      return value
    set: (value) -> @set value, { force: true, suppress: true }

  constructor: ->
    super
    @state.value = switch
      when @schema.key? then new Map
      else new Set

  update: (item, opts={}) -> switch
    when @schema.key? and @state.value.has(item.key)
      unless opts.replace
        throw @error "cannot update due to key conflict: #{item.key}"
      exists = @state.value.get(item.key)
      exists.merge item.content, opts
    when @schema.key? then @state.value.set(item.key, item)
    else @state.value.add(item)

  remove: (item) ->
    switch
      when not item? then return super
      when @schema.key?
        @state.value.delete(item.key)
      else @state.value.delete(item)
    @emit 'update', this
    @emit 'delete', item
    return this
      
  set: (value, opts={}) ->
    { force=false, replace=true, suppress=false } = opts
    @debug "[set] enter with:"
    @debug value
    @state.prev = @content
    @state.value.clear() unless opts.merge is true

    unless @mutable or force
      throw @error "cannot set data on read-only (config false) element"
    
    value = [].concat(value).filter(Boolean)
    value = switch
      when not @mutable
        @schema.validate value, @context.with(opts)
      when @schema.apply?
        @schema.apply value, @context.with(opts)
      else value
        
    @state.enumerable = @state.value.size
    
    try Object.defineProperty @container, @name,
      configurable: true
      enumerable: @state.enumerable

    @emit 'update', this unless suppress
    return this
    
  merge: (value, opts={}) ->
    @debug "[merge] merging into existing List(#{@state.value.size}) for #{@name}"
    opts.merge = true
    opts.replace ?= true
    @set value, opts
    
  create: (value) ->
    @merge value, replace: false
    
module.exports = List
