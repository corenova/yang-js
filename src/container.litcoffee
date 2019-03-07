# Container - controller of object properties

## Class Container

    debug = require('debug')('yang:container')
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property

      # @property 'content',
      #   get: ->
      #     return @state.value unless @state.value? and @children.length
      #     value = Object.create(@state.value)
      #     Object.defineProperty value, kProp, enumerable: false, value: this
      #     @children.forEach (prop) ->
      #       Object.defineProperty value, prop.name, prop
      #     Object.defineProperties value,
      #       in: value: @in.bind(this)
      #       get: value: @get.bind(this)
      #       set: value: @set.bind(this)
      #       merge: value: @merge.bind(this)
      #     return value
      
      @property 'changed',
        get: -> @state.changed or @state.changes.size

      @property 'change',
        get: -> switch
          when @changed and @state.changes.size
            obj = {}
            Array.from(@state.changes).forEach (i) -> obj[i.name] = i.change
            return obj
          when @changed then @content
          else undefined
      
      debug: -> debug @uri, arguments...

      constructor: ->
        super
        proxy = new Proxy {},
          get: (obj, prop) -> obj[prop]
          set: (obj, prop, value) =>
            schema = @locate(prop)
            switch
              when schema? and schema.nodes.length
                obj[prop] = value
                schema.eval obj, @context.with(suppress: true)
              when schema?
                obj[prop] = schema.apply value, @context.with(suppress: true)
              else
                obj[prop] = value
            
        Object.defineProperty proxy, kProp, value: this
        @state.value = proxy

      set: (value, opts={}) ->
        { force = false, suppress = false, inner = false, actor } = opts
        @clean()
        return this if value? and value is @content
        unless @mutable or not value? or force
          throw @error "cannot set data on read-only (config false) element"
        return @remove opts if value is null

        if value? and value not instanceof Object
          throw @error "cannot set non-object to a Container"

        @state.value[k] = v for own k, v of value
        
        Object.defineProperty @container, @name, enumerable: @enumerable if @attached

        @state.changed = true
        @emit 'update', this, actor unless suppress or inner
        @emit 'change', this, actor unless suppress
        @state.emit 'set', this # internal emit 
        @debug "[set] completed"
        return this

### merge

Enumerate key/value of the passed in `obj` and merge into known child
properties.

      merge: (obj, opts={ replace: true, suppress: false}) ->
        { suppress, inner, actor } = opts
        opts.replace ?= true
        
        unless @content and @schema.nodes?.length
          opts.replace = false
          return @set obj, opts
          
        return @remove opts if obj is null
        
        @clean()
        @debug "[merge] merging into existing Object(#{Object.keys(@content)}) for #{@name}"
        @debug obj
        return this unless obj instanceof Object

        opts.inner = true
        # TODO: protect this as a transaction?
        for own k, v of obj
          prop = @in(k)
          continue unless prop?
          prop.merge(v, opts)
          @state.changes.add(prop) if prop.changed

        if @changed
          @emit 'update', this, actor unless suppress or inner
          @emit 'change', this, actor unless suppress
        return this

    module.exports = Container
