# Container - controller of object properties

## Class Container

    debug = require('debug')('yang:container')
    delegate = require 'delegates'
    Emitter  = require('events').EventEmitter
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property

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
        .method 'off'

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
              when @children.has(key) then @children.get(key).data
              when key of obj then obj[key]
              when key is 'inspect' then @toJSON.bind(this)
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
          when @changed and not @active then null
          when @changed then @value

      clone: ->
        copy = super children: new Map, changes: new Set
        copy.add prop.clone(parent: copy) for prop in @props
        return copy

      debug: -> debug @uri, arguments...

      emit: (topic, target, actor) ->
        @state.emit arguments...
        
### add (child)

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

### get (key)

      get: (key) -> switch
        when key? and @children.has(key) then @children.get(key).data
        else super

### set (obj, opts)

      set: (obj, opts={}) ->
        @children.clear()
        @changes.clear()
        obj = Object.assign {}, obj if obj?[kProp] instanceof Property
        super obj, opts
        @emit 'set', this # TODO: we shouldn't need this...
        return this

### merge (obj, opts)

Enumerate key/value of the passed in `obj` and merge into known child
properties.

      merge: (obj, opts={}) ->
        return @delete opts if obj is null
        return @set obj, opts unless @children.size
        
        @clean()
        @state.prev = @value
        
        # TODO: protect this as a transaction?
        { deep = true } = opts
        subopts = Object.assign {}, opts, inner: true
        for own k, v of obj
          prop = @children.get(k) ? @in(k)
          continue unless prop? and not Array.isArray(prop)
          if deep or v is null then prop.merge(v, subopts)
          else prop.set(v, subopts)

        @commit this, opts
        return this

### delete (opts)

      delete: (opts) ->
        @children.clear()
        @changes.clear()
        super


### commit (prop, tx)

Commits the changes to the data model

      commit: (subject=this, tx={}) ->
        if subject is this # committing changes to self
          # this gets called only once per container node during transaction
          return false unless @changed
          super this, tx # propagate this change up the tree (recursive)
          if not tx.inner
            try @root.emit 'update', this, tx.actor unless tx.suppress
            catch error
              @rollback()
              throw this.error('commit error, rollback', error)
          @emit 'change', this, tx.actor unless tx.suppress
        else
          # this gets called once or more per child (if subject is changed)
          return false unless @props.some (p) -> subject is p
          @changes.add subject
          if not tx.inner # higher up the tree from transaction entry point
            tx.origin ?= subject
            super this, tx # propagate this change up the tree (recursive)
            @emit 'change', tx.origin, tx.actor unless tx.suppress
        return true

### rollback

      rollback: ->
        return @delete() unless @prev? # newly created
        prop.rollback() for prop in Array.from(@changes)
        return super

### toJSON

This call creates a new copy of the current `Property.data`
completely detached/unbound to the underlying data schema. It's main
utility is to represent the current data state for subsequent
serialization/transmission. It accepts optional argument `tag` which
when called with `true` will tag the produced object with the current
property's `@name`.

      toJSON: (key, state = true) ->
        props = @props
        value = switch
          when props.length
            obj = {}
            for prop in props when prop.enumerable and (state or prop.mutable)
              value = prop.toJSON false, state
              obj[prop.name] = value if value?
            obj
          else @value
        value = "#{@name}": value if key is true
        return value

### inspect

      inspect: ->
        output = super
        return Object.assign output, children: @children.size
        
    module.exports = Container
