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

## Class Property

    debug    = require('debug')('yang:property')
    co       = require 'co'
    delegate = require 'delegates'
    XPath    = require './xpath'
    context  = require './context'

    class Property

      @property: (prop, desc) ->
        Object.defineProperty @prototype, prop, desc

      constructor: (@name, @schema={}) ->
        unless this instanceof Property then return new Property arguments...

        @state  = 
          configurable: true
          enumerable: false
          parent: null
          value: null
          
        # Bind the get/set functions to call with 'this' bound to this
        # Property instance.  This is needed since native Object
        # Getter/Setter uses the Object itself as 'this'
        @set = @set.bind this
        @get = @get.bind this

        # soft freeze this instance
        Object.preventExtensions this

      delegate @prototype, 'state'
        .access 'parent'
        .getter 'configurable'
        .getter 'enumerable'

      delegate @prototype, 'schema'
        .getter 'kind'
        .getter 'binding'

### Computed Properties

      @property 'content',
        get: -> @state.value
        set: (value) -> @set value, force: true

      @property 'context',
        get: ->
          ctx = Object.create(context)
          ctx.property = this
          ctx.state = {}
          return ctx

      @property 'root',
        get: ->
          if @parent?.__ instanceof Property then @parent.__.root
          else this
      
      @property 'props',
        get: -> prop for k, prop of @content?.__props__
      
      @property 'key',
        get: -> switch
          when @content not instanceof Object  then undefined
          when @content.hasOwnProperty('@key') then @content['@key']
          when Array.isArray @parent
            key = undefined
            @parent.some (item, idx) => if item is @content then key = idx+1; true
            key
          
      @property 'path',
        get: ->
          return XPath.parse '/', @schema if this is @root
          entity = switch typeof @key
            when 'number' then ".[#{@key}]"
            when 'string' then ".[key() = '#{@key}']"
            else @name
          debug "[#{@name}] path: #{@parent.__.name} + #{entity}"
          @parent.__.path.append entity

## Instance-level methods

      emit: (event) ->
        return if this is @root
        debug "[#{@path}] emit '#{event}' from '#{@name}' to '#{@root.name}'"
        @root.emit arguments...

### join (obj)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It registers itself into
`obj.__props__` as well as defined in the target `obj` via
`Object.defineProperty`.

      join: (obj, opts={ replace: true, suppress: false }) ->
        return obj unless obj instanceof Object

        # when joining for the first time, apply the data found in the
        # 'obj' into the property instance
        unless @parent?
          @parent = obj
          @set obj[@name]
          return obj
          
        switch
          when Array.isArray obj
            debug "[join] list with new property: #{@name}"
            equals = (a, b) ->
              return false unless a? and b?
              if a['@key'] then a['@key'] is b['@key']
              else a is b

            unless obj.hasOwnProperty '__keys__'
              Object.defineProperty obj, '__keys__', value: []
                
            keys = obj.__keys__
            for item, idx in obj when equals item, @content
              key = item['@key']
              key = "__#{key}__" if (Number) key
              
              debug "[join] found matching key in #{idx} for #{key}"
              if @enumerable
                unless opts.replace is true
                  throw @error "key conflict for '#{@key}' already inside list"
                obj[key].__.content = @content if obj.hasOwnProperty(key)
                obj.splice idx, 1, @content
                @emit 'update', this, item unless opts.suppress
              else
                obj.splice idx, 1
                for k, i in keys when k is key
                  obj.__keys__.splice i, 1
                  delete obj[key]
                  break
                @emit 'delete', this unless opts.suppress
              return obj

            obj.push @content
            keys.push @key
            # TODO: need to register a direct key?
            #(new Property @key, @content, schema: this, enumerable: false).join obj
            @emit 'create', this unless opts.suppress
            @emit 'update', this, prev unless opts.suppress
            
          else
            debug "[join] object with new property: #{@name}"
            if @kind is 'list' and @content? and not Array.isArray(@content)
              debug @content
              throw @error "cannot join non-list array property into containing object"
            unless obj.hasOwnProperty '__props__'
              Object.defineProperty obj, '__props__', value: {}
            prev = obj.__props__[@name]
            obj.__props__[@name] = this
            Object.defineProperty obj, @name, this
            @emit 'update', this, prev unless opts.suppress
            
        return obj

### get (pattern)

This is the main `Getter` for the target object's property value. When
called with optional `pattern` it will perform an internal
[find](#find-xpath) operation to traverse/locate that value being
requested instead of returning its own `@content`.

It also provides special handling based on different types of
`@content` currently held.

When `@content` is a function, it will call it with the current
`Property` instance as the bound context (this) for the function being
called. It handles `computed`, `async`, and generally bound functions.

      get: (pattern) -> switch
        when pattern?
          match = @find pattern
          switch
            when match.length is 1 then match[0].get()
            when match.length > 1  then match.map (x) -> x.get()
            else undefined
        when @content instanceof Function then @invoke.bind this
        else
          @binding.call @context if @binding?
          # TODO: should utilize yield to resolve promises
          @content

### set (value)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (value, opts={ force: false, join: true, suppress: false }) ->
        debug "[set] setting '#{@name}' with:"
        debug value
        
        debug "[set] #{@name} attaching '__' property"
        try Object.defineProperty value, '__', configurable: true, value: this

        unless not value? or opts.force or @schema.config?.tag isnt false
          throw @error "cannot set data on read-only element"
          
        value = switch
          when @schema.apply? then @schema.apply value, @context
          else value

        try
          Object.defineProperty value, '__', value: this
          delete value[k] for own k of value when k not of value.__props__

        prev = @state.value
        @state.enumerable = value? or @binding?
        @state.value = value
        return this unless opts.join
        
        try @join @parent, opts
        catch e
          @state.value = prev
          throw e
        return this

### merge (value)

Performs a granular merge of `value` into existing `@content` if
available, otherwise performs [set](#set-value) operation.

      merge: (value, opts={ replace: true, suppress: false }) ->
        unless typeof @content is 'object' then return @set value

        value = value[@name] if value? and value.hasOwnProperty @name
        return unless typeof value is 'object'
        
        if Array.isArray @content
          debug "[merge] merging into existing Array for #{@name}"
          value = [ value ] unless Array.isArray value
          value = @schema.apply value, @context
          value.forEach (item) => item.__.join @content, opts
          # TODO: need to re-apply schema on the 'list'
        else
          # TODO: protect this as a transaction?
          @content[k] = v for k, v of value when @content.hasOwnProperty k
          # TODO: need to reapply schema to self
        return this

### create (value)

A simple convenience wrap around the above [merge](#merge-value) operation.

      create: (value) -> @merge value, replace: false

### remove

The reverse of [join](#join-obj), it will detach itself from the
`@parent` containing object.
      
      remove: ->
        @state.enumerable = false
        @state.value = undefined unless @kind is 'list'
        @join @parent
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

      find: (pattern='.', opts={}) ->
        xpath = switch
          when pattern instanceof XPath then pattern
          else XPath.parse pattern, @schema

        if opts.root or not @parent? or xpath.tag not in [ '/', '..' ]
          debug "[#{@path}] #{@name} applying '#{xpath}'"
          debug @content
          xpath.apply(@content).props
        else switch
          when xpath.tag is '/'  and @parent.__? then @parent.__.find xpath, opts
          when xpath.tag is '..' and @parent.__? then @parent.__.find xpath.xpath, opts
          else []

### invoke

A convenience wrap to a Property instance that holds a function to
perform a Promise-based execution.

      invoke: (args...) ->
        try
          unless @content instanceof Function
            throw @error "cannot invoke on a property without function"
          ctx = @context
          # TODO: need to ensure unique instance of 'input' and 'output' for concurrency
          ctx.input = args[0]
          @content.apply ctx, args
          return co -> yield Promise.resolve ctx.output
        catch e
          return Promise.reject e

### error (msg)

Provides more contextual error message pertaining to the Property instance.
          
      error: (msg, ctx=this) ->
        res = new Error "[#{@path}] #{msg}"
        res.name = 'PropertyError'
        res.context = ctx
        return res
        
### valueOf (tag)

This call creates a new copy of the current `Property.content`
completely detached/unbound to the underlying data schema. It's main
utility is to represent the current data state for subsequent
serialization/transmission. It accepts optional argument `tag` which
when called with `false` will not tag the produced object with the
property's `@name`.

      valueOf: (tag=true) ->
        copy = (src) ->
          return unless src? and typeof src isnt 'function'
          if typeof src is 'object'
            try res = new src.constructor
            catch then res = {}
            res[k] = copy v for own k, v of src
            return res
          src.constructor.call src, src
        value = copy @get()
        value ?= [] if @kind is 'list'
        if tag then "#{@name}": value
        else value

## Export Property Class

    module.exports = Property
