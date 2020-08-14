# Container - controller of object properties

## Class Container

    debug = require('debug')('yang:container')
    delegate = require 'delegates'
    Emitter  = require('events').EventEmitter
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property

      constructor: ->
        super arguments...
        @state.children = new Map
        @state.changes = new Set
        @state.locked = false
        Object.setPrototypeOf @state, Emitter.prototype
        
      delegate @prototype, 'state'
        .getter 'children'
        .getter 'changes'
        .getter 'locked'
        .method 'once'
        .method 'on'
        .method 'off'

      @property 'props',
        get: -> Array.from(@children.values())

      @property 'changed',
        get: -> @changes.size > 0

      @property 'data',
        set: (value) -> @set value, { force: true, suppress: true }
        get: ->
          value = switch
            when @binding?.get? then @binding.get @context
            else @value
          
          return value unless value instanceof Object
          
          new Proxy value,
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
            obj[prop.name] = prop.change for prop in Array.from(@changes)
            obj
          when @changed and not @active then null
          when @changed then @data

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
        @children.set child.name, child
        if @value?
          Object.defineProperty @value, child.name,
            configurable: true
            enumerable: child.active

### remove (child)

This call is used to remove a child property from map of children.

      remove: (child) ->
        @children.delete child.name
        if @value?
          delete @value[child.name]

### get (key)

      get: (key) -> switch
        when key? and @children.has(key) then @children.get(key).data
        else super arguments...

### set (obj, opts)

      set: (obj, opts={}) ->
        @children.clear()
        @changes.clear()
        # TODO: should we also clear Object.defineProperties?
        try obj = Object.assign {}, obj if kProp of obj
        super obj, opts

### merge (obj, opts)

Enumerate key/value of the passed in `obj` and merge into known child
properties.

      merge: (obj, opts={}) ->
        opts.origin ?= this
        return @delete opts if obj is null
        return @set obj, opts unless @value?
        
        # TODO: protect this as a transaction?
        { deep = true } = opts

        subopts = Object.assign {}, opts, inner: true
        for own k, v of obj
          @debug "[merge] looking for #{k} inside #{@children.size} children"
          prop = @children.get(k) ? @in(k)
          continue unless prop? and not Array.isArray(prop)
          @debug "[merge] applying value to child prop #{prop.name}"
          if deep or v is null then prop.merge(v, subopts)
          else prop.set(v, subopts)
        @update @value, opts

### delete (opts)

      delete: ->
        super arguments...
        @children.clear()
        return this

### update

Updates the value to the data model. Called *once* for each node that
is part of the change branch.

      update: (value, opts={}) ->
        opts.origin ?= this

        if value instanceof Property
          @debug "[update] changes.add #{value.name}"
          @changes.add value if value.parent is this
          if opts.inner or opts.origin is this
            return this
          # higher up from change origin
          value = @value

        @debug "[update] handle #{@changes.size} changed props:"
        @debug @children.keys()
        
        for prop from @changes
          @add prop, opts
          @changes.delete prop unless prop.changed
        super value, opts
            
        @emit 'update', this, opts
        return this

### commit (opts)

Commits the changes to the data model. Async transaction.
Events: change

      commit: (opts={}) ->
        opts.origin ?= this
        if @locked
          return new Promise (resolve, reject) => @once 'commit', (res) => resolve res
          
        @debug "[commit] #{@changes.size} changes"
        try
          @state.locked = true
          @state.setMaxListeners(10 + @changes.size)
          subopts = Object.assign {}, opts, inner: true
          await prop.commit subopts for prop from @changes when not prop.locked
          if @binding?.commit?
            @debug "[commit] execute commit binding..."
            await @binding.commit @context.with(opts)
            
          promise = @parent?.commit? opts
            .then (ok) =>
              @debug "[commit] parent returned: #{ok}"
              await @revert opts unless ok
              if ok and @changed
                @emit 'change', opts.origin, opts.actor unless opts.suppress
                @changes.clear()
              @emit 'commit', ok, opts
              return ok
          unless promise?
            if @changed
              @emit 'change', opts.origin, opts.actor unless opts.suppress
              @changes.clear()
            promise = true
        catch err
          @debug "[commit] rollback due to #{err.message}"
          await @revert opts
          @emit 'commit', false, opts
          throw @error err
        finally
          @state.locked = false

        return switch
          when opts.inner then true
          else Promise.resolve promise

      revert: (opts={}) ->
        return unless @changed
        @debug "[revert] #{@changes.size} changes"
        await prop.revert opts for prop from @changes
        await super opts
        if @active
          for prop from @changes 
            Object.defineProperty @value, prop.name,
              configurable: true
              enumerable: prop.active
        @changes.clear()

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
        output = super arguments...
        return Object.assign output, children: @children.size
        
    module.exports = Container
