# Container - controller of object properties

## Class Container

    delegate = require 'delegates'
    Emitter  = require('events').EventEmitter
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property
      logger: require('debug')('yang:container')

      constructor: ->
        super arguments...
        @state.children = new Map # committed props
        @state.pending = new Map # uncommitted changed props
        @state.delta = undefined
        @state.proxy =
          has: (obj, key) => @children.has(key) or key of obj
          get: (obj, key) => switch
            when key is kProp then this
            when key is 'toJSON' then @toJSON.bind(this)
            when @has(key) then @get(key)
            when key of obj then obj[key]
            when key is 'inspect' then @toJSON.bind(this)
            when key of this and typeof @[key] is 'function' then @[key].bind(this)
          set: (obj, key, value) => switch
            when @has(key) then @_get(key).set(value)
            else obj[key] = value
          deleteProperty: (obj, key) => switch
            when @has(key) then @_get(key).delete()
            when key of obj then delete obj[key]
        Object.setPrototypeOf @state, Emitter.prototype
        
      delegate @prototype, 'state'
        .getter 'children'
        .getter 'pending'
        .getter 'delta'
        .method 'once'
        .method 'on'
        .method 'off'
        .method 'emit'

      @property 'props',
        get: -> Array.from(@children.values())

      @property 'changed',
        get: -> @pending.size > 0 or @state.changed

      @property 'changes',
        get: -> @pending.values()

      @property 'change',
        get: -> switch
          when @changed and not @active then null
          when @changed and @pending.size
            obj = {}
            obj[prop.key] = prop.change for prop from @changes
            obj
          when @changed then @data

      @property 'data',
        set: (value) -> @set value, { force: true }
        get: ->
          value = switch
            when @binding?.get? then @binding.get @context
            else @value
          return value unless value instanceof Object
          new Proxy value, @state.proxy
      
      clone: ->
        copy = super children: new Map, pending: new Map
        copy.add prop.clone(parent: copy) for prop in @props
        return copy

### add (child)

This call is used to add a child property to map of children.

      add: (child) ->
        @children.set child.key, child
        if @value?
          Object.defineProperty @value, child.key,
            configurable: true
            enumerable: child.active

### remove (child)

This call is used to remove a child property from map of children.

      remove: (child) ->
        @children.delete child.key
        if @value?
          delete @value[child.key]

### has (key)

      has: (key) -> @children.has(key)

### get (key)

      _get: (key) -> @children.get(key)
      
      get: (key) -> switch
        when key? and @has(key) then @_get(key).data
        else super arguments...

### set (obj, opts)

      set: (obj, opts={}) ->
        # TODO: should we preserve prior changes and restore if super fails?
        @pending.clear()
        # TODO: should we also clear Object.defineProperties?
        try obj = Object.assign {}, obj if kProp of obj
        super obj, opts
        # remove all props not part of pending changes
        subopts = Object.assign {}, opts
        #prop.delete(subopts) for prop in @props when not @pending.has(prop.key)
        @props.forEach (prop) => prop.delete(subopts) unless @pending.has(prop.key)
        return this

### merge (obj, opts)

Enumerate key/value of the passed in `obj` and merge into known child
properties.

      merge: (obj, opts={}) ->
        opts.origin ?= this
        return @delete opts if obj is null
        return @set obj, opts if opts.replace or not @value?
        
        # TODO: protect this as a transaction?
        { deep = true } = opts

        subopts = Object.assign {}, opts, inner: true, replace: not deep
        for own k, v of obj
          @debug => "[merge] looking for #{k} inside #{@children.size} children"
          prop = @children.get(k) ? @in(k)
          continue unless prop? and not Array.isArray(prop)
          @debug => "[merge] applying value to child prop #{prop.key}"
          prop.merge(v, subopts)
        # TODO: we should consider evaluating schema.attrs here before update
        @update @value, opts

### update

Updates the value to the data model. Called *once* for each node that
is part of the change branch.

      _update: (value, opts) ->
        @debug => "[update] handle #{@pending.size} changed props"
        
        for prop from @changes
          @debug => "[update] child #{prop.uri} changed? #{prop.changed}"
          @add prop, opts
          @pending.delete prop.key unless prop.changed

      update: (value, opts={}) ->
        opts.origin ?= this

        if value instanceof Property
          @debug => "[update] pending.set #{value.key}"
          @pending.set value.key, value if value.parent is this
          if opts.inner or opts.origin is this
            return this
          # higher up from change origin
          value = @value

        @_update value, opts # internal update handler

        # we must clear children here if being deleted before calling super (which calls parent.update)
        @children.clear() if value is null
        super value, opts
            
        @emit 'update', this, opts
        return this

### commit (opts)

Commits the changes to the data model. Async transaction.
Events: commit, change

      commit: (opts={}) ->
        return true unless @changed
        
        if @locked
          return new Promise (resolve, reject) => @once 'commit', (res) => resolve res
          
        @debug => "[commit] #{@pending.size} changes"
        try
          @state.locked = true
          @state.delta = @change
          @state.setMaxListeners(30 + (@pending.size * 2))
          
          subopts = Object.assign {}, opts, inner: true

          # 1. traverse down the children
          await prop.commit subopts for prop from @changes when not prop.locked
          
          @debug => "[commit] execute commit binding (if any)..." unless opts.sync
          await @binding?.commit? @context.with(opts) unless opts.sync

          # TODO: enable this later after kos stops using a '.' dummy container between module and nodes
          # opts.origin = this if @pending.size > 1 or not @active
          opts.origin ?= this

          # 2. traverse up the parent (if has parent)
          promise = @parent?.commit? opts
            .then (ok) =>
              @debug => "[commit] parent returned: #{ok}"
              await @revert opts unless ok
              if ok
                @emit 'change', opts.origin, opts.actor unless opts.suppress
                @finalize()
              @emit 'commit', ok, opts
              return ok
          unless promise?
            @emit 'change', opts.origin, opts.actor unless opts.suppress
            @finalize()
            promise = true
        catch err
          @debug => "[commit] revert due to #{err.message}"
          await @revert opts
          @emit 'commit', false, opts
          throw @error err, 'commit'
        finally
          @state.locked = false

        return switch
          when opts.inner then true
          else Promise.resolve promise

      revert: (opts={}) ->
        return unless @changed
        
        @debug => "[revert] #{@pending.size} changes"
        # below is hackish but works to make a copy of current value
        # to be used as ctx.prior during revert commit binding call
        @state.value = @toJSON() 
        await prop.revert opts for prop from @changes
        @add prop for prop from @changes
        await super opts

      finalize: ->
        @pending.clear()
        super() 

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
              obj[prop.key] = value if value?
            obj
          else @value
        value = "#{@name}": value if key is true
        return value

### inspect

      inspect: ->
        output = super arguments...
        return Object.assign output, children: @children.size
        
    module.exports = Container
