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

    debug   = require('debug')('yang:property')
    Promise = require 'promise'
    XPath   = require './core/xpath'
    Emitter = require './core/emitter'

    class Property extends Emitter

      @maxTransactions = 100

      constructor: (name, value, schema={}, opts={ async: false }) ->
        unless this instanceof Property then return new Property arguments...

        # publish 'update/create/delete' events
        super 'update', 'create', 'delete'

        @name = name
        @configurable = true
        @enumerable = value? or schema.binding?

        Object.defineProperties this,
          schema:  value: schema
          state:   value: { transactable: false, queue: [] }
          parent:  value: null,  writable: true
          async:   value: opts.async, writable: true

        # Bind the get/set functions to call with 'this' bound to this
        # Property instance.  This is needed since native Object
        # Getter/Setter calls the get/set function with the Object itself
        # as 'this'
        @set = @set.bind this
        @get = @get.bind this

        # soft freeze this instance
        Object.preventExtensions this

        @set value, suppress: true

### Computed Properties

      maxqueue = @maxTransactions
      enqueue  = (prop, prev) ->
        if @state.queue.length > maxqueue
          throw @error "exceeded max transaction queue of #{maxqueue}, forgot to save()?"
        @state.queue.push { new: prop, old: prev }

      @property 'transactable',
        enumerable: true
        get: -> @state.transactable
        set: (toggle) ->
          return if toggle is @state.transactable
          if toggle is true
            Property::on.call this, 'update', enqueue
          else
            @removeListener 'update', enqueue
            @state.queue.splice(0, @state.queue.length)
          @state.transactable = toggle
          
      @property 'content',
        get: -> @state.content
        set: (value) ->
          if value instanceof Object
            Object.defineProperty value, '__', value: this
          @state.content = value

      @property 'root',  get: -> not @parent? or @schema.kind is 'module'
      
      @property 'props', get: -> prop for k, prop of @content?.__props__
      
      @property 'key',   get: -> switch
        when @content not instanceof Object  then undefined
        when @content.hasOwnProperty('@key') then @content['@key']
        when Array.isArray @parent
          key = undefined
          @parent.some (item, idx) => if item is @content then key = idx; true
          key
          
      @property 'path', get: ->
        return XPath.parse '/', @schema if @root
        x = this
        p = []
        schema = @schema
        loop
          expr = x.name
          key  = x.key
          if key?
            expr += switch typeof key
              when 'number' then "[#{key}]"
              when 'string' then "[key() = '#{key}']"
              else ''
            x = x.parent?.__ # skip the list itself
          p.unshift expr if expr?
          schema = x.schema
          break unless (x = x.parent?.__) and x.schema?.kind isnt 'module'
        return XPath.parse "/#{p.join '/'}", schema

## Instance-level methods

      emit: (event) ->
        if event in @_publishes ? []
          for x in @_subscribers when x.__ instanceof Emitter
            debug "Property.emit '#{event}' from '#{@name}' to '#{x.__.name}'"
            x.__.emit arguments...
        super

### join (obj)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It registers itself into
`obj.__props__` as well as defined in the target `obj` via
`Object.defineProperty`.

      join: (obj, opts={ replace: true, suppress: false }) ->
        return obj unless obj instanceof Object
        @parent = obj
        @subscribe obj if @enumerable
        unless Array.isArray(obj) and @schema is obj.__?.schema
          debug "[join] updating containing object with new property #{@name}"
          unless obj.hasOwnProperty '__props__'
            Object.defineProperty obj, '__props__', value: {}
          prev = obj.__props__[@name]
          obj.__props__[@name] = this
          Object.defineProperty obj, @name, this
          for x in (prev?._subscribers ? []) when x isnt obj and x instanceof Emitter
            @subscribe x
          @emit 'update', this, prev unless opts.suppress
          return obj

        equals = (a, b) ->
          return false unless a? and b?
          if a['@key'] then a['@key'] is b['@key']
          else a is b

        keys = obj.__keys__ ? []
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
        # TODO: need to register a direct key...
        #(new Property @key, @content, schema: this, enumerable: false).join obj
        @emit 'create', this unless opts.suppress
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

Also, it will try to clean-up any properties it doesn't recognize
before sending back the result.

      get: (pattern) -> switch
        when pattern?
          match = @find pattern
          switch
            when match.length is 1 then match[0].get()
            when match.length > 1  then match.map (x) -> x.get()
            else undefined
        when @content instanceof Function then switch
          when @async is true then @invoke.bind this
          when @content.computed is true then @content.call this
          else @content
        when @schema.binding?
          v = @schema.binding.call this
          v = expr.eval v for expr in @schema.exprs when expr.kind isnt 'config'
          @content = v # save for direct access
          return v
          
        # TODO: should return copy of Array to prevent direct Array manipulations
        # when @content instanceof Array
        #   copy = @content.slice()
        #   for k in @content.__keys__ ? []
        #     Object.defineProperty copy, k, @content.__props__[k]
        #   Object.defineProperty copy, '__', value: this
        
        # TODO: what to do with missing leafref that contains Error instance?
        # when @content instanceof Error then throw @content

        when @content instanceof Object
          # clean-up properties unknown to the expression (NOT fool-proof)
          for own k of @content when Number.isNaN (Number k)
            desc = (Object.getOwnPropertyDescriptor @content, k)
            delete @content[k] if desc.writable
          @content
        else @content

### set (value)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (value, opts={ force: false, replace: true, suppress: false }) ->
        debug "setting '#{@name}' with parent: #{@parent?}"
        debug value
        value = value[@name] if value? and value.hasOwnProperty @name

        @content = switch
          when opts.force is true then value
          when @schema? then @schema.apply value
          else value

        return this

### merge (value)

Performs a granular merge of `value` into existing `@content` if
available, otherwise performs [set](#set-value) operation.

      merge: (value, opts={ replace: true, suppress: false }) ->
        unless typeof @content is 'object' then return @set value

        value = value[@name] if value? and value.hasOwnProperty @name
        return unless typeof value is 'object'

        if Array.isArray @content
          debug "merging into existing Array for #{@name}"
          value = [ value ] unless Array.isArray value
          value = @schema.apply value
          value.forEach (item) => item.__.join @content, opts
          # TODO: need to re-apply schema on the 'list'
        else
          try
            @transactable = true
            @content[k] = v for k, v of value when @content.hasOwnProperty k
          catch e
            @rollback()
            throw e
          finally
            @transactable = false
          # TODO: need to reapply schema to self
        return this

### create (value)

A simple convenience wrap around the above [merge](#merge-value) operation.

      create: (value) -> @merge value, replace: false

### remove

The reverse of [join](#join-obj), it will detach itself from the
`@parent` containing object.
      
      remove: ->
        @enumerable = false
        @content = undefined unless @schema?.kind is 'list'
        @join @parent
        return this

### save

This routine clear the `@updates` transaction queue so that future
[rollback](#rollback) will reset back to this state.

      save: -> @state.queue.splice(0, @state.queue.length) # clear

### rollback

This routine will replay tracked `@updates` in reverse chronological
order (most recent -> oldest) when `@transactable` is set to
`true`. It will restore the Property instance back to the last known
[save](#save-opts) state.

      rollback: ->
        while update = @state.queue.pop()
          update.old.join update.old.parent, suppress: true
        this

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
          debug "Property.#{@name} applying '#{xpath}'"
          debug @content
          xpath.apply(@content).props
        else switch
          when xpath.tag is '/'  and @parent.__? then @parent.__.find xpath, opts
          when xpath.tag is '..' and @parent.__? then @parent.__.find xpath.xpath, opts
          else []

### invoke

A convenience wrap to a Property instance that holds a function to
perform a Promise based execution.

      invoke: (args...) ->
        unless @content instanceof Function
          throw @error "cannot invoke on a property without function"
          
        unless @async is true
          return @content.apply this, args

        args = [].concat args...
        if args.length > 1
          return Promise.all args.map (input) => @invoke input
          
        new Promise (resolve, reject) =>
          @content.call this, args[0], resolve, reject

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
        value ?= [] if @schema?.kind is 'list'
        if tag then "#{@name}": value
        else value

## Export Property Class

    module.exports = Property
