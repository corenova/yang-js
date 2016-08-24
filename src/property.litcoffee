# Property - controller of Object properties

The `Property` class is the secretive shadowy element that governs
`Object` behvaior and are bound to the `Object` via
`Object.defineProperty`. It acts like a shadow `Proxy/Reflector` to
the `Object` instance and provides tight control via the
`Getter/Setter` interfaces.

The `Property` instances attach themselves to the `Object.__` property
and are rarely accessed directly - unless you know *exactly* what
you are doing.

## Class Property

    Promise  = require 'promise'
    events   = require 'events'
    XPath    = require './xpath'
    Emitter  = require './emitter'

    class Property extends Emitter

      constructor: (name, value, opts={}) ->
        @name = name
        @configurable = opts.configurable
        @configurable ?= true
        @enumerable = opts.enumerable
        @enumerable ?= value?

        super opts.parent

        Object.defineProperties this,
          schema:  value: opts.schema
          content: value: value, writable: true
          props:  get: (-> @content?.__props__ ).bind this
          key: get: (-> switch
            when @content not instanceof Object  then undefined
            when @content.hasOwnProperty('@key') then @content['@key']
            when Array.isArray @parent
              key = undefined
              @parent.some (item, idx) =>
                if item is @content
                  key = idx
                  true
              key
          ).bind this
          path: get: (-> 
            x = this
            p = []
            loop
              expr = x.name
              key  = x.key
              if key?
                expr += switch typeof key
                  when 'number' then "[#{key}]"
                  when 'string' then "[key() = #{key}]"
                  else ''
                x = x.parent?.__ # skip the list itself
              p.unshift expr if expr?
              break unless (x = x.parent?.__) and x.schema?.kind isnt 'module'
            return XPath.parse "/#{p.join '/'}"
          ).bind this

        # Bind the get/set functions to call with 'this' bound to this
        # Property instance.  This is needed since native Object
        # Getter/Setter calls the get/set function with the Object itself
        # as 'this'
        @set = @set.bind this
        @get = @get.bind this

        # setup 'update/create/delete' event propagation up the tree
        @propagate 'update', 'create', 'delete' unless opts.detached

        if value instanceof Object
          # setup direct property access
          unless value.hasOwnProperty '__'
            Object.defineProperty value, '__', writable: true
          value.__ = this

## Instance-level methods

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
        if @name? and tag
          "#{@name}": value
        else value

### join (obj)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It registers itself into
`obj.__props__` as well as defined in the target `obj` via
`Object.defineProperty`.

      join: (obj, opts={ replace: true, suppress: false }) ->
        return obj unless obj instanceof Object
        @parent = obj
        unless Array.isArray(obj) and @schema is obj.__?.schema
          unless @name?
            throw new Error "cannot join unnamed property to an object"
            
          console.debug? "updating containing object with new property #{@name}"
          unless obj.hasOwnProperty '__props__'
            Object.defineProperty obj, '__props__', value: {}
          prev = obj.__props__[@name]
          obj.__props__[@name] = this
          Object.defineProperty obj, @name, this
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
          console.debug? "found matching key in #{idx} for #{key}"
          if @enumerable
            unless opts.replace is true
              throw new Error "key conflict for '#{@key}' already inside list"
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
        (new Property @key, @content, schema: this, enumerable: false).join obj
        @emit 'create', this unless opts.suppress
        @emit 'update', this, prev unless opts.suppress
        return obj

### set (val)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (val, opts={ force: false, merge: false, replace: true, suppress: false }) ->
        switch
          when opts.force is true then @content = val
          when opts.merge is true then switch
            when Array.isArray @content
              val = [ val ] unless Array.isArray val
              res = @schema.apply { "#{@name}": val }
              res[@name].forEach (item) => item.__.join @content, opts
            when (typeof @content is 'object') and (typeof val is 'object')
              @content[k] = v for k, v of val when @content.hasOwnProperty k
              # TODO: need to reapply schema to self
            else return @set val
          when @schema?.apply? # should check if instanceof Expression
            console.debug? "setting #{@name} with parent: #{@parent?}"
            # this is an ugly conditional...
            if @schema.kind is 'list' and val? and (not @content? or Array.isArray @content)
              val = [ val ] unless Array.isArray val
            data = switch
              when @name? then "#{@name}": val
              else val
            # TODO: enable schema.eval on anonymous 'module' from Model
            res = @schema.apply data
            @remove() if @key?
            switch
              when @name?
                prop = res.__props__[@name]
                if @parent? then prop.join @parent, opts
                else @content = prop.content
                return prop
              when @content instanceof Object
                for name, prop of res.__props__
                  prop.join @content, opts
              else @content = res
          else @content = val
        return this

The below `merge/create` routines are a convenience wrap to calling `set`

      merge:  (val) -> @set val, merge: true
      create: (val) -> @set val, merge: true, replace: false
      
      remove: ->
        @enumerable = false
        @content = undefined unless @schema?.kind is 'list'
        @join @parent
        return this

### get

This is the main `Getter` for the target object's property value. When
called with `arguments` it will perform an internal
[find](#find-xpath) operation to traverse/locate that value being
requested.

It also provides special handling based on different types of
`@content` currently held.

When `@content` is a function, it will call it with the current
`Property` instance as the bound context (this) for the function being
called. It handles `computed`, `async`, and generally bound functions.

Also, it will try to clean-up any properties it doesn't recognize
before sending back the result.

      get: -> switch
        when arguments.length
          match = @find arguments...
          switch
            when match.length is 1 then match[0]
            when match.length > 1  then match
            else undefined
        when @content instanceof Function then switch
          when @content.computed is true then @content.call this
          when @content.async is true
            (args...) => new Promise (resolve, reject) =>
              @content.apply this, [].concat args, resolve, reject
          else @content.bind this
        # when @content instanceof Array
        #   copy = @content.slice()
        #   for k in @content.__keys__ ? []
        #     Object.defineProperty copy, k, @content.__props__[k]
        #   Object.defineProperty copy, '__', value: this
        when @content instanceof Object
          # clean-up properties unknown to the expression (NOT fool-proof)
          for own k of @content when Number.isNaN (Number k)
            desc = (Object.getOwnPropertyDescriptor @content, k)
            delete @content[k] if desc.writable
          @content
        else @content

### find (pattern)

This helper routine can be used to allow traversal to other elements
in the data tree from the relative location of the current `Property`
instance. It is mainly used via [get](#get) and generally used inside
controller logic bound inside the [Yang expression](./yang.litcoffee)
as well as event handler listening on [Model](./model.litcoffee)
events. It accepts `pattern` in the form of XPATH or YPATH.

      find: (pattern) ->
        xpath = switch
          when pattern instanceof XPath then pattern
          else XPath.parse pattern, @schema
            
        unless @content instanceof Object
          return switch xpath.tag
            when '/','//' then xpath.apply @parent
            when '..' then switch
              when xpath.xpath? then xpath.xpath.apply @parent
              else XPath.parse('.').apply @parent
        xpath.apply @content

## Export Property Class

    module.exports = Property
