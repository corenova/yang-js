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
container | object | access(state) | reference to object containing this property
configurable | boolean | getter(state) | defines whether this property can be redefined
enumerable   | boolean | getter(state) | defines whether this property is enumerable
content | any | computed | getter/setter for `state.value`
context | object | computed | dynamically generated using [context](./src/context.coffee)
root  | [Property](./src/property.litcoffee) | computed | dynamically returns the root Property instance
path  | [XPath](./src/xpath.coffee) | computed | dynamically generate XPath for this Property from root

## Class Property

    debug    = require('debug')('yang:property')
    delegate = require 'delegates'
    context  = require './context'
    Yang     = require './yang'
    XPath    = require './xpath'

    class Property
      @property: (prop, desc) ->
        Object.defineProperty @prototype, prop, desc

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
          parent:    null
          container: null
          private:   false
          mutable:   `schema.config != false`
          attached:  false
          prior:     undefined
          value:     undefined
          changed:   false

        # 6. soft freeze this instance
        Object.preventExtensions this

      delegate @prototype, 'state'
        .access 'container'
        .access 'parent'
        .access 'strict'
        .getter 'mutable'
        .getter 'private'
        .getter 'pending'
        .getter 'changed'
        .getter 'attached'

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

      @property 'value',
        get: -> @state.value

      @property 'data',
        set: (value) -> @set value, { force: true, suppress: true }
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
          @state.path ?= @parent.path.clone().append @name
          return @state.path

      @property 'uri',
        get: -> @schema.datapath ? @schema.uri

## Instance-level methods

      clone: (state = {}) ->
        throw @error 'must clone with state typeof object' unless typeof state is 'object'
        copy = new @constructor this
        copy.state = Object.assign(Object.create(@state), state, origin: this)
        return copy

      debug: -> debug @uri, arguments...
      
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
        
        # @debug "[set] enter..."
        unless @mutable or not value? or opts.force
          throw @error "cannot set data on read-only (config false) element"

        if not opts.force and @binding?.set?
          try value = @binding.set @context.with(opts), value 
          catch e
            throw @error "failed executing set() binding: #{e.message}", e

        return this if value? and @equals value, @value
        
        bypass = opts.bypass and @kind in ["leaf", "leaf-list"]
        
        @debug "[set] applying schema..."        
        value = switch
          when @schema.apply? and not bypass
            subopts = Object.assign {}, opts, inner: true, suppress: true
            @schema.apply value, this, subopts
          else value
        @debug "[set] done applying schema...", value
        return this if value instanceof Error
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
        if not opts.force and @binding?.delete?
          try @binding.delete @context.with(opts), null
          catch e
            throw @error "failed executing delete() binding: #{e.message}", e
        @update null, opts

### update

Updates the value to the data model. Called *once* for each node that
is part of the change branch.

      update: (value, opts={}) ->
        opts.origin ?= this
        @state.prior = @state.value
        @state.value = value
        @state.changed = true
        @parent?.update this, opts # unless opts.suppress
        return this

### commit async transaction

Commits the changes to the data model. Called *once* for each node that
is part of the change branch.

      commit: (opts={}) ->
        opts.origin ?= this
        try
          # 1. perform commit bindings
          @debug "[commit] execute commit binding..."
          await @binding?.commit? @context.with(opts)
        catch err
          @debug "[commit] rollback due to #{err.message}"
          await @revert opts
          throw @error err
        @state.changed = false
        return true

      revert: (opts={}) ->
        try
          # 1. perform rollback bindings
          await @binding?.rollback? @context.with(opts)
          # 2. wait for delete of this property (if newly created)
          await @delete opts unless @state.prior?
          @state.value = @state.prior
          @state.changed = false

### attach (obj, parent, opts)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It defines itself in the
target `obj` via `Object.defineProperty`.

      attach: (obj, parent, opts) ->
        return obj unless obj instanceof Object
        opts ?= { replace: false, suppress: false, force: false }

        detached = true unless @container?
        @container = obj
        @parent = parent

        # if joining for the first time, apply existing data unless explicit replace
        if detached and opts.replace isnt true
          # @debug "[attach] applying existing data for #{@name} (external: #{@external}) to:"
          # @debug obj
          name = switch
            when @parent?.external and @tag of obj then @tag
            when @external then @name
            when @name of obj then @name
            else "#{@root.name}:#{@name}" # should we ensure root is kind = module?

          @set obj[name], Object.assign {}, opts, inner: true, suppress: true

        unless opts.preserve
          try Object.defineProperty obj, @name,
              configurable: true
              enumerable: @enumerable
              get: (args...) => @get args...
              set: (args...) => @set args...
            
        @state.attached = true
        @debug "[attach] attached into #{obj.constructor.name} container"
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
        @debug "[find] #{pattern}"
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
        @debug "deferring '#{@kind}(#{@name})' until update at #{@root.name}"
        @root.once 'update', =>
          @debug "applying deferred data (#{typeof value})"
          @data = value
        return value
        
### error (msg)

Provides more contextual error message pertaining to the Property instance.
          
      error: (err, ctx) ->
        err = new Error err unless err instanceof Error
        err.uri = @uri 
        err.src = this
        err.ctx = ctx
        return err

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
