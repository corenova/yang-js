# Property - controller of Object properties

The `Property` class is the *secretive shadowy* element that governs
`Object` behavior and are bound to the `Object` via
`Object.defineProperty`. It acts like a shadow `Proxy/Reflector` to
the `Object` instance and provides tight control via the
`Getter/Setter` interfaces.

Below are list of properties available to every instance of `Property`:

property | type | mapping | description
--- | --- | --- | ---
name   | string | direct | name of the property
schema | object | direct | a schema instance (usually [Yang](./src/yang.listcoffee))
state  | object | direct | *private* object holding internal state
configurable | boolean | getter(state) | defines whether this property can be redefined
enumerable   | boolean | getter(state) | defines whether this property is enumerable
content | any | computed | getter/setter for `state.value`
context | object | computed | dynamically generated using [context](./src/context.coffee)
root  | [Property](./src/property.litcoffee) | computed | dynamically returns the root Property instance
path  | [XPath](./src/xpath.coffee) | computed | dynamically generate XPath for this Property from root

## Class Property

    debug    = require('debug')
    delegate = require 'delegates'
    context  = require './context'
    Yang     = require './yang'
    XPath    = require './xpath'

    class Property
      @property: (prop, desc) ->
        Object.defineProperty @prototype, prop, desc

      logger: debug('yang:property')
      debug: (f) -> switch
        when debug.enabled @logger.namespace then switch
          when typeof f is 'function' then @logger @uri, [].concat(f())...
          else @logger @uri, arguments...
     
      constructor: (spec={}) ->
        # NOTE: ES6/CS2 does not support below
        # unless this instanceof Property then return new Property arguments...

        # 1. parse if spec is YANG definition (string)
        spec = Yang.parse spec if typeof spec is 'string'
        
        # 2. assign if spec is an instance of Yang schema
        schema = spec if spec instanceof Yang
        
        # 3. destructure spec as an object if not schema as instance
        { name, schema } = spec unless schema?
        
        # 4. parse if schema is YANG definition (string)
        schema = Yang.parse schema if typeof schema is 'string'
        schema ?= kind: 'anydata'

        # 5. initialize property instance
        @name = name ? schema.datakey
        @schema = schema
        @state = 
          strict:   false
          private:  false
          mutable:  `schema.config != false`
          attached: false
          replaced: false
          changed:  false
          locked:   false
          prior:    undefined
          value:    undefined
          parent:   null

        # 6. soft freeze this instance
        Object.preventExtensions this

      delegate @prototype, 'state'
        .access 'parent'
        .access 'strict'
        .getter 'private'
        .getter 'mutable'
        .getter 'attached'
        .getter 'replaced'
        .getter 'changed'
        .getter 'locked'
        .getter 'prior'
        .getter 'value'

      delegate @prototype, 'schema'
        .getter 'tag'
        .getter 'kind'
        .getter 'type'
        .getter 'default'
        .getter 'external'
        .getter 'binding'
        .method 'locate'
        .method 'lookup'

### Computed Properties

      @property 'key',
        get: -> @name

      @property 'value',
        get: -> @state.value

      @property 'data',
        set: (value) -> @set value, { force: true }
        get: -> switch
          when @binding?.get? then @binding.get @context
          else @value

      @property 'enumerable',
        get: -> not @private and (@value? or @binding?)

      @property 'active',
        get: -> @enumerable and @value?

      @property 'change',
        get: -> switch
          when @changed and not @active then null
          when @changed then @data

      @property 'context',
        get: ->
          ctx = Object.create(context)
          ctx.opts = {}
          ctx.node = this
          Object.preventExtensions ctx
          return ctx

      @property 'root',
        get: ->
          return this if @kind is 'module'
          root = switch
            when @parent is this then this
            when @parent instanceof Property then @parent.root
            else this
          @state.path = undefined unless @state.root is root
          return @state.root = root

      @property 'path',
        get: ->
          if this is @root
            entity = switch
              when @kind is 'module' then '/'
              else '.'
            return XPath.parse entity, @schema
          @state.path ?= @parent.path.clone().append @key
          return @state.path

      @property 'uri',
        get: -> switch
          when @parent? and @parent.uri? then "#{@parent.uri}/#{@key}"
          when @parent? then @key
          else @schema.datapath ? @schema.uri

## Instance-level methods

      clone: (state = {}) ->
        throw @error 'must clone with state typeof object' unless typeof state is 'object'
        copy = new @constructor this
        copy.state = Object.assign(Object.create(@state), state, origin: this)
        return copy

      equals: (a, b) -> switch @kind
        when 'leaf-list'
          return false unless a and b
          a = Array.from(new Set([].concat(a)))
          b = Array.from(new Set([].concat(b)))
          return false unless a.length is b.length
          a.every (x) => b.some (y) => x is y
        else a is b

### get (key)

This is the main `Getter` for the target object's property value. When
called with optional `key` it will perform an internal
[find](#find-xpath) operation to traverse/locate that value being
requested instead of returning its own `@data`.

It also provides special handling based on different types of
`@data` currently held.

      get: (key) -> switch
        when key?
          try match = @find key
          return unless match? and match.length
          switch
            when match.length is 1 then match[0].data
            when match.length > 1  then match.map (x) -> x.data
            else undefined
        else @data

### set (value)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (value, opts={}) ->
        opts.origin ?= this
        
        # @debug => "[set] enter..."
        unless @mutable or not value? or opts.force
          throw @error "cannot set data on read-only (config false) element", 'set'

        try value = @binding.set @context.with(opts), value if @binding?.set?
        catch e
          throw @error e, 'set'

        return this if value? and @equals value, @value # return if same value
        
        bypass = opts.bypass and @kind in ["leaf", "leaf-list"]
        @debug => "[set] applying schema..."        
        value = switch
          when @schema.apply? and not bypass
            subopts = Object.assign {}, opts, inner: true
            try @schema.apply value, this, subopts
            catch e then throw @error e, 'set'
          else value
        @debug => "[set] done applying schema..."
        return this if value instanceof Error
        return this if value? and @equals value, @value # return if same value

        @debug => "[set] replaced? #{@state.value?}"
        @state.replaced = @state.prior? or @state.value?
        @update value, opts

### merge (value)

Performs a granular merge of `value` into existing `@value` if
available, otherwise performs [set](#set-value) operation.

      merge: (value, opts={}) ->
        opts.origin ?= this
        return @delete opts if value is null
        return @set value, opts

### delete

      delete: (opts={}) ->
        opts.origin ?= this
        #return this if @state.value is null
        return this unless @state.value?
        if not opts.force and @binding?.delete?
          try @binding.delete @context.with(opts), null
          catch e
            throw @error e, 'delete'
        @update null, opts

### update

Updates the value to the data model. Called *once* for each node that
is part of the change branch.

      update: (value, opts={}) ->
        opts.origin ?= this

        if not @locked or opts.origin is this
          if @state.changed
            @debug "[update] already in changed state, is @state.prior already defined?", @state.prior
            @state.prior ?= @state.value
          else
            @debug "[update] currently in clean state, updating @state.prior with current data:", @state.value
            @state.prior = @state.value
        # @state.prior ?= @state.value unless @locked
        @state.changed or= @state.value isnt value
        @state.value = value

        @parent?.update this, opts
        return this

### commit async transaction

Commits the changes to the data model. Called *once* for each node that
is part of the change branch.

      lock: (opts={}) ->
        @state.locked = true
        @state.delta = @change
        opts.lock = this
        return this

      unlock: (opts={}) ->
        @state.locked = false
        # @state.delta = undefined
        delete opts.lock
        return this
      
      commit: (opts={}) ->
        return this unless @changed
        
        try
          await @lock opts
          
          # 1. perform the bound commit transaction
          if not opts.sync and @binding?.commit?
            (@debug => "[commit] execute commit binding...")
            await @binding?.commit? @context.with(opts)

          # 2. wait for the parent to commit unless called by parent
          await @parent?.commit? opts unless opts.inner

          # 3. self-clean only if no parent
          @clean opts if not @parent? 
          
        catch err
          @debug => "[commit] revert due to #{err.message}"
          await @revert opts
          throw @error err, 'commit'
          
        finally
          @unlock opts
          
        return this

      revert: (opts={}) ->
        return unless @changed

        id = opts.seq
        @debug "[revert:#{id}] changing back from:", @state.value
        @debug "[revert:#{id}] changing back to:", @state.prior
        temp = @state.value
        @state.value = @state.prior
        @state.prior = temp # preserve what we were trying to change to within commit context

        @debug "[revert:#{id}] execute binding..." unless opts.sync
        try
          await @binding?.commit? @context.with(opts) unless opts.sync
        catch err
          @debug "[revert:#{id}] failed due to #{err.message}"
          # throw @error err, 'revert'
        @debug "[revert:#{id}] cleaning up..."
        @clean opts

      clean: (opts={}) ->
        @state.changed = false
        @state.replaced = false
        @debug "[clean:#{opts.seq}] finalized commit"

### attach (obj, parent, opts)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It defines itself in the
target `obj` via `Object.defineProperty`.

      attach: (obj, parent, opts) ->
        return obj unless obj instanceof Object
        opts ?= { replace: false, force: false }
        @parent = parent

        # if joining for the first time, apply existing data unless explicit replace
        unless @attached
          # @debug "[attach] applying existing data for #{@name} (external: #{@external}) to:"
          # @debug obj
          name = switch
            when @parent?.external and @tag of obj then @tag
            when @external then @name
            when @name of obj then @name
            else "#{@root.name}:#{@name}" # should we ensure root is kind = module?

          @set obj[name], Object.assign {}, opts, inner: true

        unless opts.preserve
          try Object.defineProperty obj, @name,
              configurable: true
              enumerable: @enumerable
              get: (args...) => @get args...
              set: (args...) => @set args...
            
        @state.attached = true
        @debug => "[attach] attached into #{obj.constructor.name} container"
        return obj

### find (pattern)

This helper routine can be used to allow traversal to other elements
in the data tree from the relative location of the current `Property`
instance. It returns matching `Property` instances based on the
provided `pattern` in the form of XPATH or YPATH.

It is internally used via [get](#get) and generally used inside
controller logic bound inside the [Yang expression](./yang.litcoffee)
as well as event handler listening on [Model](./model.litcoffee)
events.

It *always* returns an array (empty to denote no match) unless it
encounters an error, in which case it will throw an Error.

      find: (pattern='.', opts={}) ->
        @debug => "[find] #{pattern}"
        pattern = XPath.parse pattern, @schema
        switch
          when pattern.tag is '/'  and this isnt @root then @root.find(pattern)
          when pattern.tag is '..' then @parent?.find pattern.xpath
          else pattern.apply(this) ? []

### in (pattern)

A convenience routine to locate one or more matching Property
instances based on `pattern` (XPATH or YPATH) from this Model.

      in: (pattern) ->
        try props = @find pattern
        return unless props? and props.length
        return switch
          when props.length > 1 then props
          else props[0]

### defer (value)

Optionally defer setting the value to the property until root has been updated.

      defer: (value) ->
        @debug => "deferring '#{@kind}(#{@name})' until update at #{@root.name}"
        @root.once 'update', =>
          @debug => "applying deferred data (#{typeof value})"
          @data = value
        return value
        
### error (msg)

Provides more contextual error message pertaining to the Property instance.
          
      error: (err, ctx) ->
        err = new Error err unless err instanceof Error
        err.uri ?= @uri
        err.src ?= this
        err.ctx ?= ctx
        return switch
          when @binding?.error? then @binding.error err
          else err

### toJSON

This call creates a new copy of the current `Property.content`
completely detached/unbound to the underlying data schema. It's main
utility is to represent the current data state for subsequent
serialization/transmission. It accepts optional argument `tag` which
when called with `true` will tag the produced object with the current
property's `@name`.

      toJSON: (key, state = true) ->
        value = switch
          when @kind is 'anydata' then undefined
          when state isnt true and not @mutable then undefined
          else @data
        value = "#{@name}": value if key is true
        return value

### inspect

      inspect: ->
        return {
          name:    @name
          kind:    @kind
          path:    @path.toString()
          active:  @active
          private: @private
          mutable: @mutable
          changed: @changed
          schema: switch
            when @schema.uri?
              uri:      @schema.uri
              summary:  @schema.description?.tag
              datakey:  @schema.datakey
              datapath: @schema.datapath
              external: @schema.external
              children: @schema.children.map (x) -> x.uri
            else false
          value: @toJSON()
        }

## Export Property Class

    module.exports = Property
