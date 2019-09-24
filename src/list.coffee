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
      # XXX - do not cache into @state.path since keys may change...
      @parent.path.clone().append entity

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
    when /^\.\./.test(pattern) and @parent?
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

  @property 'active',
    get: -> @enumerable and @children.size

  @property 'change',
    get: -> switch
      when @changed and @children.size
        Array.from(@changes)
          .filter (i) -> i.active
          .map (i) ->
            obj = i.change
            obj[k] = i.get(k) for k in i.keys if obj?
            obj
      when @changed and not @active then null
      when @changed then @value

  # private methods

  add: (child, opts={}) ->
    if @schema.key?
      key = "key(#{child.key})"
      if @children.has(key)
        throw @error "cannot update due to key conflict: #{child.key}"
      @children.set(key, child)
    else
      @children.set(child)
    @changes.add(child)

  remove: (child, opts={}) ->
    { suppress = false, actor } = opts
    switch
      when child.key? then @children.delete("key(#{child.key})")
      else @children.delete(child)
    @changes.add(child)
    @emit 'change', this, actor unless suppress
    return this

  equals: (a, b) ->
    return false unless Array.isArray(a) and Array.isArray(b) and a.length is b.length
    # figure out how to deal with empty array later...
    # return true if a.length is 0
    return false
    # a.every (x) => b.some (y) => x is y

  # public methods

  set: (data, opts) ->
    data = [].concat(data).filter(Boolean) if data?
    super data, opts

  merge: (data, opts) ->
    return @delete opts if data is null
    return @set data, opts unless @children.size
    @clean()
    @state.prev = @value
    data = [].concat(data).filter(Boolean) if data?
    creates = []
    subopts = Object.assign {}, opts, inner: true
    for item in data
      if @schema.key?
        item = @schema.key.apply item
        key = "key(#{item['@key']})"
        if @children.has(key)
          @children.get(key).merge(item, subopts)
          continue
      creates.push(item)
    @schema.apply creates, this, subopts if creates.length
    @commit opts
    return this

  # create is a list-only operation 
  create: (data, opts) ->
    return @set data, opts unless @children.size
    @clean()
    @state.prev = @value
    data = [].concat(data).filter(Boolean) if data?
    subopts = Object.assign {}, opts, inner: true
    @schema.apply data, this, subopts if data.length
    @commit opts
    return this

  toJSON: (key, state = true) ->
    value = switch
      when @children.size then @props.map (item) -> item.toJSON false, state
      else @value
    value = "#{@name}": value if key is true
    return value

module.exports = List
