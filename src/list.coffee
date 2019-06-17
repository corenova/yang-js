debug = require('debug')('yang:list')
delegate = require 'delegates'

Container = require './container'
Property = require './property'
XPath = require './xpath'
kProp = Symbol.for('property')

class ListItem extends Container

  debug: -> debug @uri, arguments...

  delegate @prototype, 'state'
    .getter 'key'

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

  attach: (obj, parent, opts) ->
    unless obj instanceof Object
      throw @error "list item must be an object"
    opts ?= { replace: false, suppress: false, force: false }
    @parent = parent
    # list item directly applies the passed in object
    @set obj, opts
    @state.key = @value?['@key']
    @parent.add this, opts
    @state.attached = true
    @emit 'attach', this
    return obj

  find: (pattern) -> switch
    # here we skip a level of hierarchy
    when /^\.\.\//.test(pattern) and @parent?
      @parent.find arguments...
    else super

  inspect: ->
    res = super
    res.key = @key
    res.keys = @keys
    return res

class List extends Container
  debug: -> debug @uri, arguments...

  @Item = ListItem

  @property 'value',
    get: -> @props.map((item) -> item.content).filter(Boolean)

  @property 'props',
    get: -> switch
      when @schema.key? then Array.from(@children.values())
      else Array.from(@children.keys())

  @property 'change',
    get: -> switch
      when @changed and @children.size
        Array.from(@changes)
          .filter (i) -> i.active
          .map (i) ->
            obj = i.change
            obj[k] = i.get(k) for k in i.keys if obj?
            obj
      when @changed then @value

  add: (child, opts={}) -> switch
    when child.key?
      key = "key(#{child.key})"
      if @children.has(key)
        exists = @children.get(key)
        unless opts.merge
          throw @error "cannot update due to key conflict: #{key}"
        exists.merge child.value, opts
        @changes.add(exists) if exists.changed
      else
        @children.set(key, child)
        @changes.add(child)
    else
      @children.set(child)
      @changes.add(child)

  remove: (child, opts={}) ->
    { suppress = false, actor } = opts
    switch
      when child.key? then @children.delete("key(#{child.key})")
      else @children.delete(child)
    @changes.add(child)

  set: (value, opts={}) ->
    value = [].concat(value).filter(Boolean)
    super value, opts
    return this

  merge: (value, opts={}) ->
    return @delete opts if value is null
    return @set value, opts unless @children.size
    @clean()
    opts.merge ?= true
    value = [].concat(value).filter(Boolean) if value?
    value = @schema.apply value, this, Object.assign {}, opts, suppress: true
    @commit opts
    return this

  toJSON: (tag = false, state = true) ->
    value = @props.map (item) -> item.toJSON false, state
    value = "#{@name}": value if tag
    return value

module.exports = List
