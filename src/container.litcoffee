# Container - controller of object properties

## Class Container

    debug = require('debug')('yang:container')
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property

      @property 'content',
        get: ->
          return @state.value unless @state.value? and @children.length
          value = Object.create(@state.value)
          Object.defineProperty value, kProp, enumerable: false, value: this
          @children.forEach (prop) ->
            Object.defineProperty value, prop.name, prop
          Object.defineProperties value,
            in: value: @in.bind(this)
            get: value: @get.bind(this)
            set: value: @set.bind(this)
            merge: value: @merge.bind(this)
          return value
      
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

      set: (value, opts={}) ->
        value = value[kProp].toJSON() if value?[kProp] instanceof Property
        super value, opts

### merge

Enumerate key/value of the passed in `obj` and merge into known child
properties.

      merge: (obj, opts={}) ->
        { replace = true, suppress = false, inner = false, deep = true, actor } = opts
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
          if deep then prop.merge(v, opts)
          else prop.set(v, opts)
          @state.changes.add(prop) if prop.changed

        if @changed
          @emit 'update', this, actor unless suppress or inner
          @emit 'change', this, actor unless suppress
        return this

    module.exports = Container
