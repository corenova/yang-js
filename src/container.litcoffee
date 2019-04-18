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
        @state.changes = new Set
        Object.setPrototypeOf @state, Emitter.prototype

      delegate @prototype, 'state'
        .getter 'children'
        .getter 'changes'
        .method 'once'
        .method 'on'

      @property 'props',
        get: -> Array.from(@children.values())

      @property 'changed',
        get: -> @changes.size > 0

      @property 'content',
        set: (value) -> @set value, { force: true, suppress: true }
        get: ->
          return @value unless @value instanceof Object
          new Proxy @value,
            has: (obj, key) => @children.has(key) or key of obj
            get: (obj, key) => switch
              when key is kProp then this
              when key is 'toJSON' then @toJSON.bind(this)
              when @children.has(key) then @children.get(key).get()
              when key of obj then obj[key]
              when key of this and typeof @[key] is 'function' then @[key].bind(this)
            set: (obj, key, value) => switch
              when @children.has(key) then @children.get(key).set(value)
              else obj[key] = value
            deleteProperty: (obj, key) =>
              @children.delete(key) if @children.has(key)
              delete obj[key] if key of obj
      
      @property 'change',
        get: -> switch
          when @changed and @children.size
            obj = {}
            obj[i.name] = i.change for i in Array.from(@changes)
            obj
          when @changed then @value

      emit: (event) ->
        @state.emit arguments...
        @root.emit arguments... unless this is @root

### add (key, child, opts)

This call is used to add a child property to map of children.

      add: (key, child) ->
        @children.set(key, child)
        @changes.add(child) if child.changed

### remove (child)

This call is used to remove a child property from map of children.

      remove: (child) ->
        @changes.add(child)

      clean: ->
        if @changed
          child.clean() for child in Array.from(@changes)
        @changes.clear()

### get

      get: (key) -> switch
        when key? and @children.has(key) then @children.get(key).get()
        else super

### set

      set: (obj, opts) ->
        @children.clear()
        @changes.clear()
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
        # @debug "[merge] merging into existing Object(#{Object.keys(@content)}) for #{@name}"
        # @debug obj

        opts.inner = true
        # TODO: protect this as a transaction?
        for own k, v of obj
          prop = @children.get(k)
          continue unless prop?
          if deep then prop.merge(v, opts)
          else prop.set(v, opts)
          @changes.add(prop) if prop.changed

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
            for prop in props when state or prop.mutable
              value = prop.toJSON false, state
              obj[prop.name] = value if value?
            obj
          else @value
        value = "#{@name}": value if tag
        return value

    module.exports = Container
