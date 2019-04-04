# Container - controller of object properties

## Class Container

    debug = require('debug')('yang:container')
    delegate = require 'delegates'
    Emitter  = require('events').EventEmitter
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property
      debug: -> debug @uri, arguments...

      constructor: ->
        super
        @state.children = new Map
        @state.removals = new Set
        Object.setPrototypeOf @state, Emitter.prototype

      delegate @prototype, 'state'
        .getter 'children'
        .getter 'removals'
        .method 'once'
        .method 'on'

      @property 'props',
        get: -> Array.from(@children.values())

      @property 'changed',
        get: -> @state.changed or @removals.size or @props.some (prop) -> prop.changed

      @property 'changes',
        get: -> @props.filter((prop) -> prop.changed).concat(Array.from(@removals))

      @property 'content',
        set: (value) -> @set value, { force: true, suppress: true }
        get: ->
          return @value unless @value instanceof Object
          new Proxy @value,
            has: (obj, key) => @children.has(key) or key of obj
            get: (obj, key) => switch
              when key is kProp then this
              when key is 'get' then @get.bind(this)
              when key is 'set' then @set.bind(this)
              when key is 'push' then @create.bind(this)
              when key is 'merge' then @merge.bind(this)
              when key is 'toJSON' then @toJSON.bind(this)
              when key of obj then obj[key]
              when @children.has(key) then @children.get(key).get()
              else obj[key]
            set: (obj, key, value) => switch
              when @children.has(key) then @children.get(key).set(value)
              else obj[key] = value
            deleteProperty: (obj, key) =>
              @children.delete(key) if @children.has(key)
              delete obj[key] if key of obj
      
      @property 'change',
        get: -> switch
          when @changed and @children.size
            changes = @props.filter (prop) -> prop.changed
            obj = {}
            obj[i.name] = i.change for i in changes
            obj
          when @changed then @content

      emit: (event) ->
        @state.emit arguments...
        unless this is @root
          @debug "[emit] '#{event}' to '#{@root.name}'"
          @root.emit arguments...

### add (key, child, opts)

This call is used to add a child property to map of children.

      add: (key, child) -> @children.set(key, child);

### remove (child)

This call is used to remove a child property from map of children.

      remove: (child) -> # noop

      clean: ->
        @removals.clear()
        if @changed
          child.clean() for child in @props
          @state.changed = false

### get

      get: (key) -> switch
        when key? and @children.has(key) then @children.get(key).get()
        else super

### set

      set: (obj, opts) ->
        @children.clear()
        @removals.clear()
        obj = obj[kProp].value if obj?[kProp] instanceof Property
        super obj, opts
        @emit 'set', this
        return this

### merge

Enumerate key/value of the passed in `obj` and merge into known child
properties.

      merge: (obj, opts={}) ->
        return @set obj, opts unless obj? and @children.size
        
        { suppress = false, inner = false, deep = true, actor } = opts
        @clean()
        @debug "[merge] merging into existing Object(#{Object.keys(@content)}) for #{@name}"
        @debug obj

        opts.inner = true
        # TODO: protect this as a transaction?
        for own k, v of obj
          prop = @children.get(k)
          continue unless prop?
          if deep then prop.merge(v, opts)
          else prop.set(v, opts)

        if @changed
          @emit 'update', this, actor unless suppress or inner
          @emit 'change', this, actor unless suppress
        return this

      create: (obj, opts={}) ->
        opts.merge = false;
        @merge obj, opts


### toJSON

This call creates a new copy of the current `Property.content`
completely detached/unbound to the underlying data schema. It's main
utility is to represent the current data state for subsequent
serialization/transmission. It accepts optional argument `tag` which
when called with `true` will tag the produced object with the current
property's `@name`.

      toJSON: (tag = false, state = true) ->
        props = @props
        value = switch
          when props.length
            obj = {}
            for prop in props
              value = prop.toJSON false, state
              obj[prop.name] = value if value?
            obj
          else @content
        value = "#{@name}": value if tag
        return value

    module.exports = Container
