# Container - controller of object properties

## Class Container

    debug = require('debug')('yang:container')
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property

      @property 'content',
        get: ->
          return @state.value unless @children.size
          new Proxy @state.value,
            has: (obj, key) => @children.has(key)
            get: (obj, key) => switch
              when key is kProp then this
              when @children.has(key) then @children.get(key).content
              else obj[key]
            set: (obj, key, value) =>
              child = @children.get(key)
              child.set(value) if child?
      
      @property 'changed',
        get: -> @state.changed or @props.some (prop) -> prop.changed

      @property 'change',
        get: -> switch
          when @changed and @children.size
            changes = @props.filter (prop) -> prop.changed
            obj = {}
            obj[i.name] = i.change for i in changes
            obj
          when @changed then @content
          else undefined

      debug: -> debug @uri, arguments...

      # set: (value, opts={}) ->
      #   value = value[kProp].toJSON false, false if value?[kProp] instanceof Property
      #   super value, opts

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
          prop = @children.get(k)
          continue unless prop?
          if deep then prop.merge(v, opts)
          else prop.set(v, opts)

        if @changed
          @emit 'update', this, actor unless suppress or inner
          @emit 'change', this, actor unless suppress
        return this

    module.exports = Container
