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

    debug    = require('debug')('yang:property') # if process.env.DEBUG?
    co       = require 'co'
    delegate = require 'delegates'
    clone    = require 'clone'
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
        # expose the BoundThis for the set/get
        @set.bound = @get.bound = this

        # soft freeze this instance
        Object.preventExtensions this

      delegate @prototype, 'state'
        .method 'once'
        .method 'on'
        .access 'container'
        .getter 'configurable'
        .getter 'enumerable'
        .getter 'mutable'
        .getter 'prev'

      delegate @prototype, 'schema'
        .getter 'kind'
        .getter 'type'
        .getter 'default'
        .getter 'binding'

### Computed Properties

      @property 'content',
        get: -> @state.value
        set: (value) -> @set value, { force: true, suppress: true }

      @property 'context',
        get: ->
          ctx = Object.create(context)
          ctx.state = {}
          ctx.property = this
          Object.preventExtensions ctx
          return ctx

      @property 'parent', get: -> @container?[kProp]

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
          key = @key
          return @state.path if @state.path? and not key?
          @debug "[path] #{@kind}(#{@name}) has #{key} #{typeof key}"
          entity = switch typeof key
            when 'number' then ".[#{key}]"
            when 'string' then ".[key('#{key}')]"
            else switch
              when @kind is 'list' then @schema.datakey
              else @name
          @debug "[path] #{@parent.name} + #{entity}"
          return @state.path = @parent.path.clone().append entity

## Instance-level methods

      clone: ->
        @debug "[clone] cloning with #{@children.length} properties"
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
attaches itself to the provided target `obj`. It defines itself in the
target `obj` via `Object.defineProperty`.

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
        if detached and opts.replace isnt true
          @debug "[join] applying existing data for #{@name} to:"
          @debug obj
          opts.suppress = true
          @set exists, opts

        # TODO: should produce meaningful warning?
        try Object.defineProperty obj, @name, this
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
          try match = @find pattern
          return unless match? and match.length
          switch
            when match.length is 1 then match[0].content
            when match.length > 1  then match.map (x) -> x.content
            else undefined
        when @kind in [ 'rpc', 'action' ] then switch
          when @binding? then @do.bind this
          else @content
        else
          if @binding? and not (@kind is 'list' and @key?)
            try return @binding.call @context
            catch e
              throw @error "issue executing registered function binding during get(): #{e.message}", e
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
            if value[kProp] instanceof Property and value[kProp] isnt this
              @debug "[set] cloning existing property for assignment"
              value = clone(value)
            value = Object.create(value) unless Object.isExtensible(value)
          Object.defineProperty value, kProp, configurable: true, value: this

        value = switch
          when @schema.apply?
            @schema.apply value, @context.with(opts)
          else value
        return this if value instanceof Error
        try
          Object.defineProperty value, kProp, value: this
          Object.defineProperty value, '$', value: @get.bind(this)
          if @schema.nodes.length and @kind isnt 'module'
            for own k of value
              desc = Object.getOwnPropertyDescriptor value, k
              if desc.writable is true and not @schema.locate(k)?
                @debug "[set] hiding non-schema defined property: #{k}"
                Object.defineProperty value, k, enumerable: false

        @state.prev = @state.value
        @state.enumerable = value? or @binding?
        
        if @binding?.length is 1 and not opts.force and @kind not in [ 'action', 'rpc' ]
          try @binding.call @context, value 
          catch e
            @debug e
            throw @error "issue executing registered function binding during set(): #{e.message}", e
        else
          @state.value = value

        try Object.defineProperty @container, @name,
          configurable: true
          enumerable: @state.enumerable

        @emit 'update', this if this is @root or not opts.suppress
        @debug "[set] completed"
        return this

### merge (value)

Performs a granular merge of `value` into existing `@content` if
available, otherwise performs [set](#set-value) operation.

      merge: (value, opts={ replace: true, suppress: false }) ->
        opts.replace ?= true
        unless @content instanceof Object and @kind is 'list'
          opts.replace = false
          return @set value, opts

        value = value[@name] if value? and value.hasOwnProperty? @name
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
              item[kProp].name -= conflicts
              if key of exists
                conflicts++
                exists[key][kProp].merge item, opts
              else
                a.push item
              return a
            ), []
            combine = @content.concat newitems
          else
            newitems = copy.content
            combine = @content.concat newitems
          attr.apply combine, @context.with(opts) for attr in @schema.attrs
          newitems.forEach (item) =>
            item[kProp].name += length
            item[kProp].join @content, opts
          @emit 'update', this unless opts.suppress
          return copy
        else
          @debug "[merge] merging into existing Object(#{Object.keys(@content).length}) for #{@name}"
          # TODO: protect this as a transaction?
          @in(k)?.merge(v, opts) for own k, v of value when @content.hasOwnProperty k
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
          #@container.splice @name, 1
          delete @container[@name]
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
          @debug @content
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
            
### do ()

A convenience wrap to a Property instance that holds a function to
perform a Promise-based execution.

Always returns a Promise.

      invoke: ->
        console.warn "DEPRECATION: please use .do() instead"
        @do arguments...
        
      do: (input={}) ->
        unless (@binding instanceof Function) or (@content instanceof Function)
          return Promise.reject @error "cannot perform action on a property without function"
        transaction = true if @root.kind is 'module' and @root.transactable isnt true
        try
          @debug "[do] executing method: #{@name}"
          @debug input
          @root.transactable = true if transaction
          ctx = @context
          ctx.state[kProp] = this
          @schema.input?.eval  ctx.state, {}
          @schema.output?.eval ctx.state, {}
          ctx.input = input
          # first apply schema bound function (if availble), otherwise
          # execute assigned function (if available and not 'missing')
          if @binding?
            @debug "[do] calling bound function with: #{Object.keys(input)}"
            @debug @binding.toString()
            res = @binding.call ctx, input
            ctx.output ?= res
          else
            @debug "[do] calling assigned function: #{@content.name}"
            @debug @content.toString()
            ctx.output = @content.call @container, input
          return co =>
            @debug "[do] evaluating output schema"
            ctx.output = yield Promise.resolve ctx.output
            @debug "[do] finish setting output"
            @emit 'done', ctx
            if transaction
              @root.save()
              @root.transactable = false
            return ctx.output
        catch e
          @debug e
          if transaction
            @root.rollback()
            @root.transactable = false
          return Promise.reject e

### error (msg)

Provides more contextual error message pertaining to the Property instance.
          
      error: (msg, ctx=this) ->
        at = "#{@path}"
        at += @name if at is '/'
        err = new Error "[#{at}] #{msg}"
        err.name = 'PropertyError'
        err.context = ctx
        @emit 'error', err, this
        return err

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
current property's `@name`.

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
