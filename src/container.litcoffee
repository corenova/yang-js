# Container - controller of object properties

## Class Container

    debug    = require('debug')('yang:container')
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property
      @property 'changed',
        get: -> @state.changed or @state.changes.size

      @property 'change',
        get: ->
          return @content unless @state.changes.size
          obj = {}
          Array.from(@state.changes).forEach (i) -> obj[i.name] = i.change
          return obj
      
      debug: -> debug @uri, arguments...

### set

Calls `Property.set` with a *shallow clone* of the object value being
passed in.

      set: (value, opts) ->
        return this unless value?

        unless @kind is 'grouping'
          value = Object.create(value) # make a shallow clone
          Object.defineProperty value, kProp, configurable: true, value: this
          Object.defineProperty value, '$', value: @in.bind(this)
        
        super

        # if @schema.nodes.length and @kind isnt 'module'
        #   for own k of value
        #     desc = Object.getOwnPropertyDescriptor value, k
        #     if desc.writable is true and not @schema.locate(k)?
        #       @debug "[set] hiding non-schema defined property: #{k}"
        #       Object.defineProperty value, k, enumerable: false

        return this

      merge: (value, opts={ replace: true, suppress: false}) ->
        { suppress, actor } = opts
        opts.replace ?= true
        # unless @attached
        #   @debug "[merge] defer until after join"
        #   console.warn "[merge] defer until after join"
        #   @once 'join', => @merge value, opts
        #   return this
        
        unless @content and @schema.nodes?.length
          opts.replace = false
          return @set value, opts
          
        return @remove opts if value is null
        
        @clean()
        @debug "[merge] merging into existing Object(#{Object.keys(@content)}) for #{@name}"
        @debug value
        # TODO: we shouldn't need this...
        value = value[@name] if value? and value.hasOwnProperty? @name
        return this unless value instanceof Object

        opts.suppress = true
        # TODO: protect this as a transaction?
        for own k, v of value
          prop = @in(k)
          continue unless prop?
          prop.merge(v, opts)
          @state.changes.add(prop) if prop.changed

        @emit 'update', this, actor if not suppress and @changed
        return this

    module.exports = Container
