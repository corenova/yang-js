# Property - controller of Object properties

The `Property` class is the *secretive shadowy* element that governs
`Object` behavior and are bound to the `Object` via
`Object.defineProperty`. It acts like a shadow `Proxy/Reflector` to
the `Object` instance and provides tight control via the
`Getter/Setter` interfaces.

The `Property` instances attach themselves to the `Object.__` property
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

    debug    = require('debug')('yang:property') if process.env.DEBUG?
    co       = require 'co'
    delegate = require 'delegates'
    Emitter  = require('events').EventEmitter
    context  = require './context'
    XPath    = require './xpath'

    class Property

      @property: (prop, desc) ->
        Object.defineProperty @prototype, prop, desc

      constructor: (@name, @schema={}) ->
        unless this instanceof Property then return new Property arguments...

        @state = 
          value: null
          container: null
          configurable: true
          enumerable: @binding?
          mutable: @schema.config?.valueOf() isnt false
        Object.setPrototypeOf @state, Emitter.prototype

        @schema.kind ?= 'anydata'
          
        # Bind the get/set functions to call with 'this' bound to this
        # Property instance.  This is needed since native Object
        # Getter/Setter uses the Object itself as 'this'
        @set = @set.bind this
        @get = @get.bind this

        # soft freeze this instance
        Object.preventExtensions this

      delegate @prototype, 'state'
        .method 'once'
        .method 'on'
        .access 'container'
        .getter 'configurable'
        .getter 'enumerable'
        .getter 'mutable'

      delegate @prototype, 'schema'
        .getter 'kind'
        .getter 'type'
        .getter 'binding'

### Computed Properties

      @property 'content',
        get: -> @state.value
        set: (value) -> @set value, force: true

      @property 'context',
        get: ->
          ctx = Object.create(context)
          ctx.state = {}
          ctx.property = this
          Object.preventExtensions ctx
          return ctx

      @property 'parent', get: -> @container?.__

      @property 'root',
        get: ->
          return this if @kind is 'module'
          root = switch
            when @parent instanceof Property then @parent.root
            else this
          @state.path = undefined unless @state.root is root
          return @state.root = root
      
      @property 'props',
        get: -> prop for k, prop of @content?.__props__
      
      @property 'key',
        get: ->
          return unless @schema is @parent?.schema
          switch
            when @content not instanceof Object  then @name + 1
            when @content.hasOwnProperty('@key') then @content['@key']
            when Array.isArray @container
              for idx, item of @container when item is @content
                idx = Number(idx) unless (Number.isNaN (Number idx))
                return idx+1
              return undefined

      @property 'path',
        get: ->
          if this is @root
            entity = switch
              when @kind is 'module' then '/'
              else '.'
            return XPath.parse entity, @schema
          return @state.path if @state.path?
          key = @key
          @debug "[path] #{@kind}(#{@name}) has #{key} #{typeof key}"
          entity = switch typeof key
            when 'number' then ".[#{key}]"
            when 'string' then ".[key() = '#{key}']"
            else switch
              when @kind is 'list' then @schema.datakey
              else @name
          @debug "[path] #{@parent.name} + #{entity}"
          return @state.path = @parent.path.clone().append entity

## Instance-level methods

      clone: ->
        @debug "[clone] cloning with #{@props.length} properties"
        copy = (new @constructor @name, @schema)
        copy.state[k] = v for k, v of @state
        return copy
        
      emit: (event) ->
        @state.emit arguments...
        unless this is @root
          @debug "[emit] '#{event}' to '#{@root.name}'"
          @root.emit arguments...

### join (obj)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It registers itself into
`obj.__props__` as well as defined in the target `obj` via
`Object.defineProperty`.

      join: (obj, opts={ replace: false, suppress: false, force: false }) ->
        return obj unless obj instanceof Object

        detached = true unless @container?
        @container = obj

        if Array.isArray(obj) and Array.isArray(@content)
          @debug @content
          throw @error "cannot join array property into list container"
        if @kind is 'list' and not Array.isArray(obj) and @content? and not Array.isArray(@content)
          throw @error "cannot join non-list array property into containing object"

        # if joining for the first time, apply existing data unless explicit replace
        exists = obj[@name] 
        Object.defineProperty obj, @name, this
        
        if detached and opts.replace isnt true
          opts.suppress = true
          @set exists, opts

        unless obj.hasOwnProperty '__props__'
          Object.defineProperty obj, '__props__', value: {}
        obj.__props__[@name] = this
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

      get: (pattern, prop=false) -> switch
        when pattern? and prop then @in pattern
        when pattern?
          match = @find pattern
          switch
            when match.length is 1 then match[0].content
            when match.length > 1  then match.map (x) -> x.content
            else undefined
        when @kind in [ 'rpc', 'action' ] then switch
          when @binding? then @do.bind this
          else @content
        else
          try @binding.call @context if @binding? and not (@kind is 'list' and @key?)
          catch e then throw @error "issue executing registered function binding during get()", e
          # TODO: should utilize yield to resolve promises
          @content

### set (value)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (value, opts={ force: false, suppress: false }) ->
        @debug "[set] enter with:"
        @debug value
        #@debug opts
        return this if value is @content and not opts.force
        unless @mutable or not value? or opts.force
          throw @error "cannot set data on read-only element"
          
        try
          unless value instanceof Function
            value = value.__.toJSON false if value.__ instanceof Property and value.__ isnt this
            value = Object.create(value) unless Object.isExtensible(value)
          Object.defineProperty value, '__', configurable: true, value: this
            
        value = switch
          when @schema.apply?
            @schema.apply value, @context.with(opts)
          else value
        return this if value instanceof Error
        try
          Object.defineProperties value,
            '__': value: this
            '$':  value: @get.bind(this)
          if @schema.nodes.length and @kind isnt 'module'
            for own k of value
              desc = Object.getOwnPropertyDescriptor value, k
              if desc.writable is true
                @debug "[set] hiding non-schema defined property: #{k}"
                Object.defineProperty value, k, enumerable: false

        @state.prev = @state.value
        @state.enumerable = value? or @binding?
        
        if @binding?.length is 1 and not opts.force
          try @binding.call @context, value 
          catch e
            throw @error "issue executing registered function binding during set()", e
        else
          @state.value = value

        try Object.defineProperty @container, @name, enumerable: @state.enumerable

        @emit 'update', this if this is @root or not opts.suppress
        @debug "[set] completed"
        return this

### merge (value)

Performs a granular merge of `value` into existing `@content` if
available, otherwise performs [set](#set-value) operation.

      merge: (value, opts={ replace: true, suppress: false }) ->
        opts.replace ?= true
        unless @content instanceof Object
          opts.replace = false
          return @set value, opts

        value = value[@name] if value? and value.hasOwnProperty @name
        return this unless value instanceof Object
        
        if Array.isArray @content
          length = @content.length
          @debug "[merge] merging into existing Array(#{length}) for #{@name}"
          @debug value
          # here we clone this Property and update with only the newly merged values
          # XXX - this logic needs refinement, it doesn't handle min-elements condition properly
          value = [ value ] unless Array.isArray value
          copy = @clone()
          copy.set value, force: opts.force, suppress: true
          @debug "[merge] combining and applying schema"
          if @schema.key? and opts.replace
            exists = {}
            @content.forEach (item) ->
              key = item['@key']
              exists[key] = item
            @debug "[merge] reducing existing keys"
            conflicts = 0
            newitems = copy.content.reduce ((a, item) ->
              key = item['@key']
              item.__.name -= conflicts
              if key of exists
                conflicts++
                exists[key].__.merge item
              else
                a.push item
              return a
            ), []
            combine = @content.concat newitems
          else
            newitems = copy.content
            combine = @content.concat newitems
          attr.apply combine for attr in @schema.attrs
          newitems.forEach (item) =>
            item.__.name += length
            item.__.join @content, opts
          @emit 'update', copy unless opts.suppress
          return copy
        else
          @debug "[merge] merging into existing Object(#{Object.keys(@content).length}) for #{@name}"
          # TODO: protect this as a transaction?
          @content[k] = v for own k, v of value when @content.hasOwnProperty k
          # TODO: need to reapply schema to self
          return this

### create (value)

A simple convenience wrap around the above [merge](#merge-value) operation.

      create: (value) ->
        if not @content? and @kind is 'list' and not Array.isArray value
          value = [ value ] 
        res = @merge value, replace: false
        @emit 'create', res
        return res

### remove

The reverse of [join](#join-obj), it will detach itself from the
`@container` parent object.
      
      remove: ->
        return this unless @container?
        if @key?
          @container.splice @name, 1
          #delete @parent[@name]
        else
          @state.enumerable = false
          @state.value = undefined unless @kind is 'list'
          Object.defineProperty @container, @name, enumerable: false
        @emit 'update', @parent if @parent?
        @emit 'delete', this
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
        xpath = switch
          when pattern instanceof XPath then pattern
          else XPath.parse pattern, @schema
        @debug "[find] #{pattern} starting with #{xpath.tag}"
        if opts.root or not @container? or xpath.tag not in [ '/', '..' ]
          @debug "[find] #{pattern} using '#{xpath}'"
          @debug @content
          xpath.apply(@content).props ? []
        else switch
          when xpath.tag is '/'  and @parent? then @parent.find xpath, opts
          when xpath.tag is '..' and @parent? then @parent.find xpath.xpath, opts
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
            
### do (args...)

A convenience wrap to a Property instance that holds a function to
perform a Promise-based execution.

      invoke: ->
        console.warn "DEPRECATION: please use .do() instead"
        @do arguments...
        
      do: (args...) ->
        unless @content instanceof Function
          return Promise.reject @error "cannot perform action on a property without function"
        try
          @debug "[do] executing #{@name} method"
          ctx = @context.with('__': this)
          @schema.input?.eval  ctx.state
          @schema.output?.eval ctx.state
          ctx.input = args[0] ? {}
          @content.apply ctx, args
          return co =>
            @debug "[do] evaluating output schema"
            ctx.output = yield Promise.resolve ctx.output
            @debug "[do] finish setting output"
            return ctx.output
        catch e
          return Promise.reject e

### error (msg)

Provides more contextual error message pertaining to the Property instance.
          
      error: (msg, ctx=this) ->
        at = "#{@path}"
        at += @name if at is '/'
        res = new Error "[#{at}] #{msg}"
        res.name = 'PropertyError'
        res.context = ctx
        return res

      debug: (msg) ->
        if debug? then switch typeof msg
          when 'object' then debug msg
          else
            node = this
            prefix = [ @name ]
            prefix.unshift node.name while (node = node.parent)
            debug "[#{prefix.join('/')}] #{msg}"

### inspect

      inspect: ->
        return {
          name:   @schema.tag ? @name
          kind:   @schema.kind
          key:    @key
          xpath:  @path.toString()
          schema: @schema.toJSON tag: false, extended: true
          active: @enumerable
          readonly: not @mutable
        }
        
### toJSON

This call creates a new copy of the current `Property.content`
completely detached/unbound to the underlying data schema. It's main
utility is to represent the current data state for subsequent
serialization/transmission. It accepts optional argument `tag` which
when called with `false` will not tag the produced object with the
property's `@name`.

      toJSON: (tag=true) ->
        copy = (src) ->
          return unless src? and typeof src isnt 'function'
          if typeof src is 'object'
            try res = new src.constructor
            catch then res = {}
            for own k, v of src when typeof v isnt 'function'
              res[k] = copy v
            return res
          src.constructor.call src, src
        value = copy @get()
        value ?= [] if @kind is 'list'
        if tag
          name = switch
            when @kind is 'list' then @schema.datakey
            else @name
          "#{name}": value
        else value

## Export Property Class

    module.exports = Property
