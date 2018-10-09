{ Property } = require '..'

debug = require('debug')('yang:property:list') if process.env.DEBUG?
kProp = Symbol.for('property')

class ListItem extends Property

  @property 'key',
    get: -> @content?['@key']

  @property 'path',
    get: ->
      key = @key
      @debug "[path] #{@kind}(#{@name}) has #{key}"
      entity = switch typeof key
        when 'string' then ".['#{key}']"
        else '.'
      @debug "[path] #{@parent.name} + #{entity}"
      return @state.path = @parent.path.clone().append entity

  @property 'container',
    get: -> @parent.container

  @property 'parent',
    get: -> @state.parent
    set: (value) -> @state.parent = value

  constructor: (data, parent) ->
    super parent.name, parent.schema
    @parent = parent
    @set data, { force: true, suppress: true }

  remove: ->
    if @schema.key?
      @parent.state.value.delete(@key)
    else
      @parent.state.value.delete(this)
    @emit 'update', @parent
    @emit 'delete', this
    return this

  inspect: ->
    res = super
    res.key = @key
    return res

class List extends Property

  @Item = ListItem
  
  @property 'content',
    get: ->
      return unless @state.value?
      value = Array.from(@state.value.values()).map (li) -> li.content
      Object.defineProperty value, kProp, value: this
      Object.defineProperty value, '$', value: @get.bind(this)
      return value
    set: (value) -> @set value, { force: true, suppress: true }

  set: (value, opts={}) ->
    value = [].concat(value).filter(Boolean)
    @debug "[set] enter with:"
    @debug value
    value = switch
      when @schema.apply?
        @schema.apply value, @context.with(opts)
      else value
    @state.prev = @state.value
    @state.enumerable = value.length > 0

    if @schema.key?
      @state.value = new Map
      value.forEach (v) => @state.value.set(v.key, v)
    else
      @state.value = new Set
      value.forEach (v) => @state.value.add(v)

    try Object.defineProperty @container, @name,
      configurable: true
      enumerable: @state.enumerable

    @emit 'update', this unless opts.suppress
    return this
    
  merge: (value, opts) ->
    { replace=true } = opts
    return @set value, opts unless @state.value
      
    @debug "[merge] merging into existing List(#{@state.value.size}) for #{@name}"
    @debug value
    value = [].concat(value) if value?
    value = switch
      when @schema.apply?
        @schema.apply value, @context.with(opts)
      else value
        
    for item in value
      if @schema.key?
        if @state.value.has(item.key)
          unless replace is true
            throw @error "cannot merge due to key conflict: #{item.key}"
          exists = @state.value.get(item.key)
          exists.merge item.content, opts
        else
          @state.value.set(item.key, item)
      else
        @state.value.add(item)
    # TODO: need to enforce min/max elements...
        
    @emit 'update', this unless opts.suppress
    return value
    
  create: (value) ->
    @merge value, replace: false

    
module.exports = List
