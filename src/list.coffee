debug = require('debug')('yang:list')
delegate = require 'delegates'

Container = require './container'
Property = require './property'
XPath = require './xpath'
kProp = Symbol.for('property')

class ListItem extends Container

  debug: -> debug @uri, arguments...

  @property 'key',
    get: -> @state.value?['@key']

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

  join: (obj, parent, opts) ->
    unless obj instanceof Object
      throw @error "list item must be an object"
    opts ?= { replace: false, suppress: false, force: false }

    @container = parent?.container
    @parent = parent
    # list item directly applies the passed in object
    @set obj, opts
    @parent.add @key, this, opts
    @state.attached = true
    @emit 'attached', this
    return obj

  find: (pattern) -> switch
    # here we skip a level of hierarchy
    when /^\.\.\//.test(pattern) and @parent?
      @parent.find arguments...
    else super

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

class List extends Container
  debug: -> debug @uri, arguments...

  @Item = ListItem

  @property 'props',
    get: -> switch
      when @schema.key? then Array.from(@children.values())
      else Array.from(@children.keys())
  
  @property 'change',
    get: -> switch
      when @changed and @children.size
        @changes.map (i) ->
          obj = i.change
          obj[k] = i.get(k) for k in i.keys if obj?
          obj
      when @changed then @content

  add: (key, child, opts={}) -> switch
    when key? and @children.has(key)
      unless opts.replace
        throw @error "cannot update due to key conflict: #{key}"
      @children.get(key).merge child.content, opts
    when key? then @children.set(key, child)
    else @children.set(child)

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
    value = [].concat(value).filter(Boolean)
    super value, opts
    return this

  merge: (value, opts={}) ->
    { suppress = false, inner = false, deep = true, actor } = opts
    @clean()
    value = [].concat(value).filter(Boolean)
    value = @schema.apply value, this, { replace: true, suppress: true }
    @state.value.push value...
    if @changed
      @emit 'update', this, actor unless suppress or inner
      @emit 'change', this, actor unless suppress
      # @emit 'create', this, actor unless suppress or replace
    return this
    
  toJSON: (tag = false, state = true) ->
    value = @props.map (item) -> item.toJSON false, state
    value = "#{@name}": value if tag
    return value

module.exports = List
