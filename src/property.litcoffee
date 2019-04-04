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
props | array(Property) | computed | returns children Property instances
key   | string/number | computed | conditionally returns unique key for Property if a list item
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
        .getter 'mutable'
        .getter 'private'
        .getter 'prev'
        .getter 'value'
        .getter 'attached'
        .getter 'changed'

      delegate @prototype, 'schema'
        .getter 'kind'
        .getter 'type'
        .getter 'default'
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
        get: -> @enumerable or @binding?

      @property 'change',
        get: -> @content
          
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
        get: -> [ @parent?.uri, @schema.tag ? @name ].filter(Boolean).join ':'

## Instance-level methods

      clone: ->
        @debug "[clone] cloning with #{@props.length} properties"
        copy = (new @constructor @name, @schema)
        copy.state[k] = v for k, v of @state
        return copy

      emit: (event) -> @parent?.emit? arguments...

      clean: -> @state.changed = false

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
            throw @error "issue executing registered function binding during get(): #{e.message}", e
        else @content

### set (value)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (value, opts={}) ->
        { force = false, suppress = false, inner = false, actor } = opts
        
        @state.changed = false
        @debug "[set] enter..."

        return this if value? and value is @value
        unless @mutable or not value? or force
          throw @error "cannot set data on read-only (config false) element"
          
        return @detach opts if value is null and @kind isnt 'leaf'

        @state.prev = @value

        if @binding?.length is 1 and not force
          try value = @binding.call @context, value 
          catch e
            throw @error "issue executing registered function binding during set(): #{e.message}", e

        @debug "[set] applying schema..."
        value = switch
          when @schema.apply?
            @schema.apply value, this, Object.assign {}, opts, suppress: true
          else value
        @debug "[set] done applying schema...", value
        return this if value instanceof Error

        @state.value = value
        # update enumerable state on every set operation
        try Object.defineProperty @container, @name, configurable: true, enumerable: @enumerable if @attached
          
        @state.changed = true
        @emit 'update', this, actor unless suppress or inner
        @emit 'change', this, actor unless suppress
        @debug "[set] completed"
        return this

### merge (value)

Performs a granular merge of `value` into existing `@content` if
available, otherwise performs [set](#set-value) operation.

      merge: (value, opts) ->
        @set value, Object.assign {}, opts, merge: true

### attach (obj, parent, opts)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It defines itself in the
target `obj` via `Object.defineProperty`.

      attach: (obj, parent, opts={}) ->
        return obj unless obj instanceof Object
        opts ?= { replace: false, suppress: false, force: false }

        detached = true unless @container?
        @container = obj
        @parent = parent

        # if joining for the first time, apply existing data unless explicit replace
        if detached and opts.replace isnt true
          @debug "[join] applying existing data for #{@name} to:"
          @debug obj
          opts.suppress = true
          @set obj[@name], opts

        @parent?.add? @name, this, opts # add to parent
        
        try Object.defineProperty obj, @name,
            configurable: true
            enumerable: @enumerable
            get: => @get arguments...
            set: => @set arguments...
            
        @state.attached = true
        @debug "[join] attached into #{obj.constructor.name} container"
        @emit 'attach', this
        return obj

### detach

The reverse of [join](#join-obj), it will detach itself from the
`@container` parent object.
      
      detach: (opts={}) ->
        { suppress, inner, actor } = opts
        
        @state.prev = @value
        @state.value = null
        
        @parent?.remove? this, opts
        try Object.defineProperty @container, @name, enumerable: false if @container?
        
        @emit 'update', this, actor unless suppress or inner
        @emit 'change', this, actor unless suppress
        return this

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
        unless err instanceof Error
          err = new Error err
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

      toJSON: (tag = false, state = true) ->
        value = switch
          when @kind is 'anydata' then undefined
          else @content
        value = "#{@name}": value if tag
        return value

### inspect

      inspect: ->
        return {
          name:   @schema.tag ? @name
          kind:   @schema.kind
          xpath:  @path.toString()
          schema: @schema.toJSON? tag: false, extended: true
          active: @active
          changed: @changed
          readonly: not @mutable
        }

## Export Property Class

    module.exports = Property
