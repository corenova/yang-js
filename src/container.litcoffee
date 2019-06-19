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
        get: -> @state.changed or @changes.size > 0

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
            deleteProperty: (obj, key) => switch
              when @children.has(key) then @children.get(key).delete()
              when key of obj then delete obj[key]
      
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

### add (child, opts)

This call is used to add a child property to map of children.

      add: (child) ->
        @children.set(child.name, child)
        @changes.add(child) if child.changed

### remove (child)

This call is used to remove a child property from map of children.

      remove: (child) ->
        # XXX - we don't remove from children...
        # @children.delete(child.name)
        @changes.add(child)

      clean: ->
        if @changed
          child?.clean?() for child in Array.from(@changes)
        @changes.clear()
        @state.changed = false

### get

      get: (key) -> switch
        when key? and @children.has(key) then @children.get(key).get()
        else super

### set

      set: (obj, opts) ->
        @children.clear()
        @changes.clear()
        # XXX - below doesn't work for list
        obj = obj[kProp].value if obj?[kProp] instanceof Property
        super obj, opts
        @emit 'set', this
        return this

### delete

      delete: (opts) ->
        @children.clear()
        @changes.clear()
        super

### merge

Enumerate key/value of the passed in `obj` and merge into known child
properties.

      merge: (obj, opts={}) ->
        return @delete opts if obj is null
        return @set obj, opts unless @children.size
        @clean()
        # @debug "[merge] merging into existing Object(#{Object.keys(@content)}) for #{@name}"
        # @debug obj

        @state.prev = @value
        # TODO: protect this as a transaction?
        { deep = true } = opts
        for own k, v of obj
          prop = @children.get(k) ? @in(k)
          continue unless prop? and not Array.isArray(prop)
          options = Object.assign {}, opts, inner: true
          if deep or v is null then prop.merge(v, options)
          else prop.set(v, options)
        @commit opts
        return this

      create: (obj, opts={}) ->
        opts.merge = false;
        @merge obj, opts

      rollback: ->
        return @delete() unless @prev? # newly created
        prop.rollback() for prop in Array.from(@changes)
        return super

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
            for prop in props when prop.active and (state or prop.mutable)
              value = prop.toJSON false, state
              obj[prop.name] = value if value?
            obj
          else @value
        value = "#{@name}": value if tag
        return value

    module.exports = Container
