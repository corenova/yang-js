# Property - controller of Object properties

The `Property` class is the *secretive shadowy* element that governs
`Object` behavior and are bound to the `Object` via
`Object.defineProperty`. It acts like a shadow `Proxy/Reflector` to
the `Object` instance and provides tight control via the
`Getter/Setter` interfaces.

The `Property` instances attach themselves to the `Object[Symbol.for('property')]` property
and are rarely accessed directly - but they are the **fundamental**
actors that *actualize* YANG schema compliance into ordinary JS
objects.

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
    XPath    = require './xpath'

    class Property
      @property: (prop, desc) ->
        Object.defineProperty @prototype, prop, desc

      constructor: (@name, @schema={}) ->
        unless this instanceof Property then return new Property arguments...

        @state = 
          value: undefined
          parent: null
          container: null
          private: false
          mutable: @schema.config?.valueOf() isnt false
          attached: false
          changed: false
          
        @schema.kind ?= 'anydata'
          
        # soft freeze this instance
        Object.preventExtensions this

      debug: -> debug @uri, arguments...
      
      delegate @prototype, 'state'
        .access 'container'
        .access 'parent'
        .access 'strict'
        .getter 'mutable'
        .getter 'private'
        .getter 'prev'
        .getter 'value'
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

      @property 'enumerable',
        get: -> not @private and (@value? or @binding?)

      @property 'content',
        set: (value) -> @set value, { force: true, suppress: true }
        get: -> @value

      @property 'active',
        get: -> @enumerable and @value?

      @property 'change',
        get: -> switch
          when @changed and not @active then null
          when @changed then @content

      @property 'context',
        get: ->
          ctx = Object.create(context)
          ctx.state = {}
          ctx.property = this
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

      emit: (event) -> @parent?.emit? arguments...

      clean: -> @state.changed = false

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
requested instead of returning its own `@content`.

It also provides special handling based on different types of
`@content` currently held.

When `@content` is a function, it will call it with the current
`@context` instance as the bound context for the function being
called.

      get: (key) -> switch
        when key? 
          try match = @find key
          return unless match? and match.length
          switch
            when match.length is 1 then match[0].get()
            when match.length > 1  then match.map (x) -> x.get()
            else undefined
        when @binding?
          try @binding.call @context
          catch e
            throw @error e, 'getter'
        else @content

### set (value)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (value, opts={}) ->
        @state.changed = false
        # @debug "[set] enter..."

        unless @mutable or not value? or opts.force
          throw @error "cannot set data on read-only (config false) element"
          
        if @binding?.length is 1 and not opts.force
          try value = @binding.call @context, value 
          catch e
            throw @error e, 'setter'

        return this if value? and @equals value, @value
        
        @state.prev = @value
        bypass = opts.bypass and @kind in ["leaf", "leaf-list"]
        # @debug "[set] applying schema..."
        value = switch
          when @schema.apply? and not bypass
            @schema.apply value, this, Object.assign {}, opts, suppress: true
          else value
        # @debug "[set] done applying schema...", value
        return this if value instanceof Error or @equals value, @prev
        
        @state.value = value
        @state.changed = true
        
        # update enumerable state on every set operation
        try Object.defineProperty @container, @name, configurable: true, enumerable: true if @attached

        @commit opts
        # @debug "[set] completed"
        return this

### delete

      delete: (opts={}) ->
        if @binding?.length is 1 and not opts.force
          try @binding.call @context, null
          catch e
            throw @error "failed executing delete() binding: #{e.message}", e
        @state.prev = @value
        @state.value = null

        @parent?.remove? this, opts # remove from parent
        
        # update enumerable state on every set operation
        try Object.defineProperty @container, @name, enumerable: false if @attached

        @state.changed = true
        @commit opts
        return this

### merge (value)

Performs a granular merge of `value` into existing `@content` if
available, otherwise performs [set](#set-value) operation.

      merge: (value, opts) ->
        return @delete opts if value is null
        @set value, Object.assign {}, opts, merge: true

### commit (opts)

Commits the changes to the data to the data model

      commit: (opts={}) ->
        return unless @changed
        if @attached and @parent?
          @parent.changes.add this
          @parent.commit suppress: true
          
        { suppress = false, inner = false, actor } = opts
        return if suppress
        unless inner
          try @emit 'update', this, actor
          catch error
            # console.warn('commit error, rolling back!');
            @rollback()
            throw error
        @emit 'change', this, actor if @attached

      rollback: ->
        @state.value = @prev
        @clean()
        return this

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
          # @debug "[join] applying existing data for #{@name} (external: #{@external}) to:"
          # @debug obj
          name = switch
            when @parent?.external and @tag of obj then @tag
            when @external then @name
            when @name of obj then @name
            else "#{@root.name}:#{@name}" # should we ensure root is kind = module?
          @set obj[name], Object.assign {}, opts, suppress: true

        @parent?.add? this, opts # add to parent

        try Object.defineProperty obj, @name,
            configurable: true
            enumerable: @enumerable
            get: => @get arguments...
            set: => @set arguments...
            
        @state.attached = true
        # @debug "[join] attached into #{obj.constructor.name} container"
        @emit 'attach', this
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
          @content = value
        return value
        
### error (msg)

Provides more contextual error message pertaining to the Property instance.
          
      error: (err, ctx=this) ->
        err = new Error err unless err instanceof Error
        err.uri = @uri 
        err.src = this
        err.ctx = ctx
        return err

### throw (msg)

      throw: (err) -> throw @error(err)

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
          else @value
        value = "#{@name}": value if key is true
        return value

### inspect

      inspect: ->
        return {
          name:   @tag ? @name
          kind:   @kind
          xpath:  @path.toString()
          schema: @schema.toJSON? tag: false, extended: true
          active: @active
          changed: @changed
          readonly: not @mutable
          content: @value
        }

## Export Property Class

    module.exports = Property
