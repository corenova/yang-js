debug = require('debug')('yang:list')
delegate = require 'delegates'

Container = require './container'
Property = require './property'
XPath = require './xpath'

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

  attach: (obj, parent, opts) ->
    unless obj instanceof Object
      throw @error "list item must be an object"
    opts ?= { replace: false, suppress: false, force: false }
    @parent = parent
    # list item directly applies the passed in object
    @set obj, opts
    @state.key = @value?['@key']
    @state.attached = true
    # @emit 'attach', this
    return obj

  find: (pattern) -> switch
    # here we skip a level of hierarchy
    when /^\.\./.test(pattern) and @parent?
      @parent.find arguments...
    else super arguments...

  inspect: ->
    res = super arguments...
    res.key = @key
    res.keys = @keys
    return res

class List extends Container
  debug: -> debug @uri, arguments...

  @Item = ListItem

  @property 'value',
    get: -> @props.map((item) -> item.data).filter(Boolean)

  @property 'props',
    get: -> switch
      when @schema.key? then Array.from(@children.values())
      else Array.from(@children.keys())

  @property 'active',
    get: -> @enumerable and @children.size > 0

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
    return unless child.active
    if @schema.key?
      key = "key(#{child.key})"
      if @children.has(key) and @children.get(key) isnt child
        throw @error "cannot update due to key conflict: #{child.key}"
      @children.set(key, child)
    else
      @children.set(child)

  remove: (child, opts={}) ->
    switch
      when child.key? then @children.delete("key(#{child.key})")
      else @children.delete(child)

  equals: (a, b) ->
    return false unless Array.isArray(a) and Array.isArray(b) and a.length is b.length
    # figure out how to deal with empty array later...
    # return true if a.length is 0
    return false
    # a.every (x) => b.some (y) => x is y

  # public methods

  set: (data, opts={}) ->
    if data? and not Array.isArray(data)
      throw @error "list must be an array"
    data = [].concat(data).filter(Boolean) if data?
    super data, opts

  merge: (data, opts={}) ->
    opts.origin ?= this
    data = [].concat(data).filter(Boolean) if data?
    return @delete opts if data is null
    return @set data, opts if not @children.size or opts.replace

    creates = []
    subopts = Object.assign {}, opts, inner: true
    for item in data
      if @schema.key? and not opts.createOnly
        item = @schema.key.apply item
        key = "key(#{item['@key']})"
        if @children.has(key)
          @debug "[merge] merge into list item for #{key}"
          @debug item
          @children.get(key).merge(item, subopts)
          @debug "[merge] merge done for list item #{key}"
          continue
      creates.push(item)
    @schema.apply creates, this, subopts if creates.length
    @update @value, opts

  update: (value, opts) ->
    @remove value if value instanceof ListItem and not value.active
    super value, opts

  toJSON: (key, state = true) ->
    value = switch
      when @children.size then @props.map (item) -> item.toJSON false, state
      else @value
    value = "#{@name}": value if key is true
    return value

module.exports = List
