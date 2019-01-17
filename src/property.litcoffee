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
    equal    = require('deep-equal')
    Emitter  = require('events').EventEmitter
    context  = require './context'
    XPath    = require './xpath'
    kProp    = Symbol.for('property')

    class Property
      @property: (prop, desc) ->
        Object.defineProperty @prototype, prop, desc

      constructor: (@name, @schema={}) ->
        unless this instanceof Property then return new Property arguments...

        @state = 
          value: undefined
          parent: null
          container: null
          configurable: true
          enumerable: @binding?
          mutable: @schema.config?.valueOf() isnt false
          attached: false
          changed: false
          changes: new Set
          
        Object.setPrototypeOf @state, Emitter.prototype

        @schema.kind ?= 'anydata'
          
        # Bind the get/set functions to call with 'this' bound to this
        # Property instance.  This is needed since native Object
        # Getter/Setter uses the Object itself as 'this'
        @set = @set.bind this
        @get = @get.bind this
        # expose the BoundThis for the set/get
        @set.bound = @get.bound = this

        # soft freeze this instance
        Object.preventExtensions this

      debug: -> debug @uri, arguments...
      
      delegate @prototype, 'state'
        .method 'once'
        .method 'on'
        .access 'container'
        .access 'parent'
        .getter 'configurable'
        .getter 'enumerable'
        .getter 'mutable'
        .getter 'prev'
        .getter 'attached'

      delegate @prototype, 'schema'
        .getter 'kind'
        .getter 'type'
        .getter 'default'
        .getter 'binding'

### Computed Properties

      @property 'content',
        get: -> @state.value
        set: (value) -> @set value, { force: true, suppress: true }

      @property 'active',
        get: -> @enumerable or @binding?

      @property 'changed',
        get: -> @state.changed

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
      
      @property 'children',
        get: ->
          return [] unless @content instanceof Object
          children = []
          for own k of @content
            desc = Object.getOwnPropertyDescriptor(@content, k)
            children.push desc.get.bound if desc?.get?.bound instanceof Property
          return children
      
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
        get: -> [ @parent?.uri, @name ].join '/'

## Instance-level methods

      clone: ->
        @debug "[clone] cloning with #{@children.length} properties"
        copy = (new @constructor @name, @schema)
        copy.state[k] = v for k, v of @state
        return copy

      clean: ->
        if @changed
          child.clean() for child in @children
          @state.changes.clear()
          @state.changed = false
        
      emit: (event) ->
        @state.emit arguments...
        unless this is @root
          @debug "[emit] '#{event}' to '#{@root.name}'"
          @root.emit arguments...

### join (obj, ctx)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It defines itself in the
target `obj` via `Object.defineProperty`.

      join: (obj, ctx={}) ->
        return obj unless obj instanceof Object
        { property: parent, state: opts } = ctx
        opts ?= { replace: false, suppress: false, force: false }

        detached = true unless @container?
        @container = obj
        @parent = parent ? obj[kProp]

        # if joining for the first time, apply existing data unless explicit replace
        if detached and opts.replace isnt true
          @debug "[join] applying existing data for #{@name} to:"
          @debug obj
          opts.suppress = true
          @set obj[@name], opts

        # TODO: should produce meaningful warning?
        try Object.defineProperty obj, @name, this
        @state.attached = true
        @debug "[join] attached into #{obj.constructor.name} container"
        return obj

### get (pattern)

This is the main `Getter` for the target object's property value. When
called with optional `pattern` it will perform an internal
[find](#find-xpath) operation to traverse/locate that value being
requested instead of returning its own `@content`.

It also provides special handling based on different types of
`@content` currently held.

When `@content` is a function, it will call it with the current
`@context` instance as the bound context for the function being
called.

      get: (pattern) -> switch
        when pattern?
          try match = @find pattern
          return unless match? and match.length
          switch
            when match.length is 1 then match[0].content
            when match.length > 1  then match.map (x) -> x.content
            else undefined
        when @binding?
          try return @binding.call @context
          catch e
            throw @error "issue executing registered function binding during get(): #{e.message}", e
        else @content

### set (value)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (value, opts={}) ->
        { force = false, suppress = false, actor } = opts
        @clean()
        @debug "[set] enter with:"
        @debug value
        #@debug opts

        return this if value? and equal(value, @content)
        unless @mutable or not value? or force
          throw @error "cannot set data on read-only (config false) element"
        return @remove opts if value is null and @kind isnt 'leaf'

        @debug "[set] applying schema..."
        ctx = @context.with(opts).with(suppress: true)
        value = switch
          when not @mutable
            @schema.validate value, ctx
          when @schema.apply?
            @schema.apply value, ctx
          else value
        return this if value instanceof Error

        @state.prev = @state.value
        @state.enumerable = value? or @binding?
        
        if @binding?.length is 1 and not force
          try @binding.call ctx, value 
          catch e
            @debug e
            throw @error "issue executing registered function binding during set(): #{e.message}", e
        else
          @state.value = value

        # TODO: do we need this block?
        if @container?.hasOwnProperty @name
          Object.defineProperty @container, @name,
            configurable: @state.configurable
            enumerable: @state.enumerable

        @state.changed = true
        @emit 'update', this, actor unless suppress
        @debug "[set] completed"
        return this

### merge (value)

Performs a granular merge of `value` into existing `@content` if
available, otherwise performs [set](#set-value) operation.

      merge: (value, opts={}) ->
        opts.merge = true
        opts.replace ?= true
        @set value, opts

### remove

The reverse of [join](#join-obj), it will detach itself from the
`@container` parent object.
      
      remove: (opts={}) ->
        { suppress, actor } = opts
        @state.enumerable = false
        @state.value = null
        return this unless @container?
        Object.defineProperty @container, @name, enumerable: false
        
        @emit 'update', this, actor unless suppress
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
        unless pattern instanceof XPath
          if /^\.\.\//.test(pattern) and @parent?
            return @parent.find pattern.replace(/^\.\.\//, ''), opts
          if /^\//.test(pattern) and this isnt @root
            return @root.find pattern, opts
          pattern = XPath.parse pattern, @schema
          
        @debug "[find] using #{pattern}"
        if opts.root or not @container? or pattern.tag not in [ '/', '..' ]
          @debug "[find] apply #{pattern}"
          pattern.apply(@content).props ? []
        else switch
          when pattern.tag is '/'  and @parent? then @parent.find pattern, opts
          when pattern.tag is '..' and @parent? then @parent.find pattern.xpath, opts
          else []

### in (pattern)

A convenience routine to locate one or more matching Property
instances based on `pattern` (XPATH or YPATH) from this Model.

      in: (pattern) ->
        try props = @find pattern
        return unless props? and props.length
        return switch
          when props.length > 1 then props
          else props[0]
            
### error (msg)

Provides more contextual error message pertaining to the Property instance.
          
      error: (err, ctx) ->
        unless err instanceof Error
          err = new Error err
        err.uri = @uri 
        err.src = this
        err.ctx = ctx if ctx?
        @root.emit 'error', err
        return err

### inspect

      inspect: ->
        return {
          name:   @schema.tag ? @name
          kind:   @schema.kind
          xpath:  @path.toString()
          schema: @schema.toJSON? tag: false, extended: true
          active: @active
          readonly: not @mutable
        }
        
### toJSON

This call creates a new copy of the current `Property.content`
completely detached/unbound to the underlying data schema. It's main
utility is to represent the current data state for subsequent
serialization/transmission. It accepts optional argument `tag` which
when called with `true` will tag the produced object with the current
property's `@name`.

      toJSON: (tag=false) ->
        copy = (src, ctx) ->
          return unless src? and typeof src isnt 'function'
          return if ctx? and ctx.kind is 'anydata'
          if typeof src is 'object'
            prop = src[kProp]
            try res = new src.constructor
            catch then res = {}
            for own k, v of src when typeof v isnt 'function'
              res[k] = copy v, prop?.in(k)
            return res
          src.constructor.call src, src
        value = copy @get()
        if tag
          name = @schema.datakey ? @name
          "#{name}": value
        else value

## Export Property Class

    module.exports = Property
