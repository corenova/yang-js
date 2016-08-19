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
        unless name? and opts instanceof Object
          console.log arguments
          throw new Error "must supply 'name' and 'opts' to create a new Property"

        @name = name
        @configurable  = opts.configurable
        @configurable ?= true
        @enumerable    = opts.enumerable
        @enumerable   ?= value?

        super opts.parent

        Object.defineProperties this,
          schema: value: opts.schema
          path:
            get: (-> # this is a little too complicated...
              x = this
              p = []
              loop
                expr = x.name
                if x.schema?.kind is 'list' and x.content?
                  if Array.isArray x.content
                    expr = undefined if p.length
                  else
                    key = x.content['@key']
                    expr = switch
                      when key? then "#{x.name}[key() = #{key}]"
                      else
                        x.parent.some (item,idx) -> if item is x.content
                          key = idx
                          true
                        "#{x.name}[#{key}]"
                    x = x.parent?.__
                p.unshift expr if expr?
                break unless (x = x.parent?.__) and x.schema?.kind isnt 'module'
              return "/#{p.join '/'}"
            ).bind this
          content:
            get: -> value
            set: ((val) ->
              @emit 'update', this if val isnt value
              value = val
            ).bind this

        # Bind the get/set functions to call with 'this' bound to this
        # Property instance.  This is needed since native Object
        # Getter/Setter calls the get/set function with the Object itself
        # as 'this'
        @set = @set.bind this
        @get = @get.bind this

        # setup 'update/create/delete' event propagation up the tree
        @propagate 'update', 'create', 'delete'

        if value instanceof Object
          # setup direct property access
          unless value.hasOwnProperty '__'
            Object.defineProperty value, '__', writable: true
          value.__ = this

## Instance-level methods

      valueOf: ->
        value = @get()
        value ?= [] if @schema?.kind is 'list'
        "#{@name}": value

### join (obj)

This call is the primary mechanism via which the `Property` instance
attaches itself to the provided target `obj`. It registers itself into
`obj.__props__` as well as defined in the target `obj` via
`Object.defineProperty`.

      join: (obj) ->
        return obj unless obj instanceof Object
        @parent = obj

        # update containing object with this property for reference
        unless obj.hasOwnProperty '__props__'
          Object.defineProperty obj, '__props__', value: {}
        prev = obj.__props__[@name]
        obj.__props__[@name] = this

        if obj instanceof Array and @schema?.kind is 'list' and @content?
          for item, idx in obj
            switch
              when item['@key']? and item['@key'] isnt @content['@key'] then continue
              when item isnt @content then continue
            console.debug? "found matching key in #{idx}"
            if @enumerable
              obj.splice idx, 1, @content
            else
              obj.splice idx, 1
              @emit 'delete', this, @content
            return obj
          obj.push @content
          @emit 'create', this, @content
        else
          Object.defineProperty obj, @name, this
        @emit 'update', this, prev
        return obj

### set (val)

This is the main `Setter` for the target object's property value.  It
utilizes internal `@schema` attribute if available to enforce schema
validations.

      set: (val, opts={ force: false, merge: false }) ->
        switch
          when opts.force is true then @content = val
          when opts.merge is true then switch
            when Array.isArray @content
              val = [ val ] unless Array.isArray val
              res = @schema.apply { "#{@name}": val }
              res[@name].forEach (item) => item.__.join @content
            when (typeof @content is 'object') and (typeof val is 'object')
              @content[k] = v for k, v of val when @content.hasOwnProperty k
            else return @set val
          when @schema?.apply? # should check if instanceof Expression
            console.debug? "setting #{@name} with parent: #{@parent?}"
            if @schema.kind is 'list' and val? and (not @content? or Array.isArray @content)
              val = [ val ] unless Array.isArray val
            res = @schema.apply { "#{@name}": val }
            if @schema.kind is 'list' and @content? and not Array.isArray @content
              @remove()
            prop = res.__props__[@name]
            if @parent? then prop.join @parent
            else @content = prop.content
            return prop
          else @content = val
        return this

The below `merge` routine is a convenience wrap to calling `set` with `merge: true`

      merge: (val) -> @set val, merge: true
      
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

### find

This helper routine can be used to allow traversal to other elements
in the data tree from the relative location of the current `Property`
instance. It is mainly used via [get](#get) and generally used inside
controller logic bound inside the [Yang expression](./yang.litcoffee)
as well as event handler listening on [Model](./model.litcoffee)
events.

      find: (xpath) ->
        xpath = new XPath xpath unless xpath instanceof XPath
        unless @content instanceof Object
          return switch xpath.tag
            when '/'  then xpath.apply @parent
            when '..' then xpath.xpath?.apply @parent
        xpath.apply @content

## Export Property Class

    module.exports = Property
