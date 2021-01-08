delegate = require 'delegates'

Container = require './container'
Property = require './property'
XPath = require './xpath'

class ListItem extends Container
  logger: require('debug')('yang:list:item')

  delegate @prototype, 'state'
    .getter 'key'

  @property 'uri',
    get: -> switch
      when @parent? then "#{@parent.uri}['#{@key}']"
      else @schema.datapath ? @schema.uri
            
  # @property 'uri',
  #   get: -> (@schema.datapath ? @schema.uri) + "['#{@key}']" 

  @property 'keys',
    get: -> if @schema.key then @schema.key.tag else []

  @property 'pos',
    get: -> (@parent.props.findIndex (x) => x is this) + 1 if @parent?

  @property 'path',
    get: ->
      entity = switch
        when @keys.length then ".['#{@key}']"
        else ".[#{@pos}]"
      unless @parent?
        return XPath.parse entity, @schema
      # XXX - do not cache into @state.path since keys may change...
      @parent.path.clone().append entity

  merge: ->
    prevkey = @key
    super arguments...
    unless prevkey is @key
      @parent?.remove? key: prevkey 
    return this

  _update: (value, opts) ->
    super arguments...
    # @debug => "[update] prior key is: #{@key}"
    @state.key = value['@key'] if @keys.length and value? and ('@key' of value)
    # @debug => "[update] current key is: #{@key}"

  attach: (obj, parent, opts) ->
    unless obj instanceof Object
      throw @error "list item must be an object", 'attach'
    opts ?= { replace: false, force: false }
    @parent = parent
    @state.key = this unless @keys.length
    # list item directly applies the passed in object
    @set obj, opts
    @state.attached = true
    return obj

  revert: (opts) ->
    return unless @changed
    await super opts
    @parent?.update this

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
  logger: require('debug')('yang:list')

  @Item = ListItem
  @property 'value',
    get: -> switch
      when @state.value? then @props.map((item) -> item.data).filter(Boolean)
      else []

  @property 'props',
    get: -> switch
      when @schema.key? then Array.from(@children.values())
      else Array.from(@children.keys())

  @property 'changed',
    get: -> @pending.size > 0 or (@state.changed and not @active)
        
  @property 'active',
    get: -> @enumerable and @children.size > 0

  @property 'change',
    get: -> switch
      when @changed and not @active then null
      when @changed and @pending.size
        Array.from(@changes)
          .filter (i) -> i.active
          .map (i) ->
            obj = i.change
            obj[k] = i.get(k) for k in i.keys if obj?
            obj

  # private methods

  _key: (s) -> "key(#{s})"

  add: (child, opts={}) ->
    return unless child.active
    if @schema.key?
      key = @_key(child.key)
      if @has(key) and @_get(key) isnt child
        @pending.delete child.key
        throw @error "cannot update due to key conflict: #{child.key}", 'add'
      @children.set(key, child)
    else
      @children.set(child)

  remove: (child, opts={}) ->
    if @schema.key?
      key = @_key(child.key)
      @children.delete(key) if @_get(key) is child
    else @children.delete(child)

  equals: (a, b) ->
    return false unless Array.isArray(a) and Array.isArray(b) and a.length is b.length
    # figure out how to deal with empty array later...
    # return true if a.length is 0
    return false
    # a.every (x) => b.some (y) => x is y

  # public methods

  has: (key) -> typeof key is 'string' and @schema.key? and super(key)

  set: (data, opts={}) ->
    if data? and not Array.isArray(data)
      throw @error "list must be an array", 'set'
    data = [].concat(data).filter(Boolean) if data?
    prev = @props
    @children.clear()
    try super data, opts
    catch err
      @children.clear()
      prev.forEach (prop) => @add prop
      throw err
    return this

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
        key = @_key(item['@key'])
        if @has(key)
          @debug => "[merge] merge into list item for #{key}"
          @debug => item
          @_get(key).merge(item, subopts)
          @debug => "[merge] merge done for list item #{key}"
          continue
      creates.push(item)
    try @schema.apply creates, this, subopts if creates.length
    catch e then throw @error e, 'create'
    @update @value, opts

  update: (value, opts) ->
    @remove value if value instanceof ListItem and not value.active
    super value, opts

  revert: (opts={}) ->
    return unless @changed
    return super opts unless @replaced

    # TODO: find a more optimal way to revert entire list?
    @debug => "[revert] complete list..."
    @set @state.prior, force: true # this will trigger 'update' events!
    (@debug => "[revert] execute binding...") unless opts.sync
    try await @binding?.commit? @context.with(opts) unless opts.sync
    catch err
      @debug => "[revert] failed due to #{err.message}"
      throw @error err, 'revert'
    @clean opts

  toJSON: (key, state = true) ->
    value = switch
      when @children.size then @props.map (item) -> item.toJSON false, state
      else @value
    value = "#{@name}": value if key is true
    return value

module.exports = List
