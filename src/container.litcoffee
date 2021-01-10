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
        @state.locked = false
        @state.proxy =
          has: (obj, key) => @children.has(key) or key of obj
          get: (obj, key) => switch
            when key is kProp then this
            when key is '_' then this
            when key is 'toJSON' then @toJSON.bind(this)
            when @has(key) then @get(key)
            when key of obj then obj[key]
            when key is 'inspect' then @toJSON.bind(this)
            when key of this and typeof @[key] is 'function' then @[key].bind(this)
            when typeof key is 'string' and key[0] is '_' then @[key.substring(1)]
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
        .getter 'locked'
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
        get: -> Array.from(@pending.values())

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
          if value.parent is this
            @pending.set value.key, value 
            @debug => "[update] pending.set '#{value.key}' now have #{@pending.size} pending changes"
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

      lock: (opts={}) ->
        randomize = (min, max) -> Math.floor(Math.random() * (max - min)) + min
        opts.seq ?= randomize 1000, 9999
        @debug "[lock:#{opts.seq}] acquiring lock... already have it?", (opts.lock is this)
        return this if opts.lock is this
        while @locked
          await (new Promise (resolve) => @once 'ready', -> resolve true)
          #await @parent?.lock opts unless opts.inner
        @debug "[lock:#{opts.seq}] acquired and has #{@pending.size} changes, changed? #{@changed}"
        @debug "[lock:#{opts.seq}] acquired by #{opts.caller.uri} and locked? #{opts.caller.locked}" if opts.caller?
        super opts

      unlock: (opts={}) ->
        @debug "[unlock:#{opts.seq}] freeing lock..."
        return this unless @locked
        super opts
        @emit 'ready'
        return this

      commit: (opts={}) ->
        try
          await @lock opts
          if @changed
            id = opts.seq ? 0
            subopts = Object.assign {}, opts, caller: this, inner: true
            delete subopts.lock
            # 1. commit all the changed children
            @debug "[commit:#{id}] wait to commit all the children..."
            await Promise.all @changes.filter((p) -> not p.locked).map (prop) -> prop.commit subopts
            if not opts.sync and @binding?.commit? and @changed
              @debug "[commit:#{id}] execute commit binding...", @changed
              await @binding.commit @context.with(opts)
            # wait for the parent to commit unless called by parent
            opts.origin ?= this
            subopts = Object.assign {}, opts, caller: this
            await @parent?.commit? subopts unless opts.inner
            @emit 'change', opts.origin, opts.actor unless opts.suppress
            @clean opts unless opts.inner
        catch err
          @debug "[commit:#{id}] error: #{err.message}"
          failed = true
          throw @error err, 'commit'
        finally
          @debug "[commit:#{id}] finalizing..."
          await @revert opts if failed
          @debug "[commit:#{id}] #{@pending.size} changes, now have #{@children.size} props, releasing lock!"
          @unlock opts

        return this

      revert: (opts={}) ->
        return unless @changed
        
        id = opts.seq ? 0
        @debug => "[revert:#{id}] #{@pending.size} changes"
        
        # below is hackish but works to make a copy of current value
        # to be used as ctx.prior during revert commit binding call
        @state.value = @toJSON()

        # XXX: may want to consider Promise.all here
        for prop from @changes when (not prop.locked) or (prop is opts.caller)
          await prop.revert opts
          @debug "[revert:#{id}] re-add changed prop"
          @add prop
        await super opts
        @debug "[revert:#{id}] have #{@children.size} remaining props"

      clean: (opts={}) ->
        return unless @changed
        # traverse down committed nodes and clean their state
        # console.warn(opts.caller) if opts.caller
        id = opts.seq
        @debug "[clean:#{id}] #{@pending.size} changes with #{@children.size} props"
        for prop from @changes when (not prop.locked) or (prop is opts.caller)
          prop.clean opts
          @pending.delete(prop.key)
        @debug "[clean:#{id}] #{@pending.size} remaining changes"
        super opts
        
        

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
