debug = require('debug')('yang:list')
delegate = require 'delegates'

Container = require './container'
Property = require './property'
XPath = require './xpath'
kProp = Symbol.for('property')

class ListItem extends Container

  debug: -> debug @uri, arguments...

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

  constructor: (data, parent) ->
    super parent.name, parent.schema
    @container = parent.container
    @parent = parent
    @state.value = data

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
  
  # @property 'content',
  #   get: ->
  #     value = Array.from(@state.value.values()).map (li) -> li.content
  #     Object.defineProperty value, kProp, enumerable: false, value: this
  #     Object.defineProperties value,
  #       in: value: @in.bind(this)
  #       get: value: @get.bind(this)
  #       set: value: @set.bind(this)
  #       merge: value: @merge.bind(this)
  #       create: value: @create.bind(this)
  #     return value
        
  @property 'change',
    get: -> switch
      when @changed and @children.size
        changes = @props.filter (prop) -> prop.changed
        changes.map (i) ->
          obj = i.change
          obj[k] = i.get(k) for k in i.keys if obj?
          obj
      when @changed then @content

  add: (item, opts={}) -> switch
    when item.key? and @children.has(item.key)
      unless opts.replace
        throw @error "cannot update due to key conflict: #{item.key}"
      @children.get(item.key).merge item.content, opts
    when item.key? then @children.set(item.key, item)

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
    { force = false, suppress = false, replace = true, inner = false, actor } = opts
    value = [].concat(value).filter(Boolean)
    super value, opts
    @state.value.forEach (item, idx) => @add new ListItem(item, this)
    return this

  merge: (value, opts={}) ->
    { replace = true, suppress = false, inner = false, deep = true, actor } = opts
    if @changed
      @emit 'update', this, actor unless suppress or inner
      @emit 'change', this, actor unless suppress
      @emit 'create', this, actor unless suppress or replace
    
  create: (value, opts={}) ->
    opts.replace = false;
    @merge value, opts

  toJSON: (tag = false, state = true) ->
    value = @props.map (item) -> item.toJSON false, state
    value = "#{@name}": value if tag
    return value

module.exports = List
