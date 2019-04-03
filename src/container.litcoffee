# Container - controller of object properties

## Class Container

    debug = require('debug')('yang:container')
    Property = require('./property')
    kProp = Symbol.for('property')

    class Container extends Property
      debug: -> debug @uri, arguments...

      @property 'content',
        set: (value) -> @set value, { force: true, suppress: true }
        get: ->
          return @value unless @value instanceof Object
          new Proxy @value,
            has: (obj, key) => @children.has(key) or key in obj
            get: (obj, key) => switch
              when key is kProp then this
              when key is 'get' then @get.bind(this)
              when key is 'set' then @set.bind(this)
              when key is 'push' then @create.bind(this)
              when key is 'merge' then @merge.bind(this)
              when key is 'toJSON' then @toJSON.bind(this)
              when key in obj then obj[key]
              when @children.has(key) then @children.get(key).get()
              else obj[key]
            set: (obj, key, value) => switch
              when @children.has(key) then @children.get(key).set(value)
              else obj[key] = value
            deleteProperty: (obj, key) =>
              @children.delete(key) if @children.has(key)
              delete obj[key] if key in obj
      
      @property 'change',
        get: -> switch
          when @changed and @children.size
            changes = @props.filter (prop) -> prop.changed
            obj = {}
            obj[i.name] = i.change for i in changes
            obj
          when @changed then @content

### merge

Enumerate key/value of the passed in `obj` and merge into known child
properties.

      merge: (obj, opts={}) ->
        return @set obj, opts unless @children.size
        
        { replace = true, suppress = false, inner = false, deep = true, actor } = opts
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

      create: (obj, opts={}) ->
        opts.replace = false;
        @merge value, opts

    module.exports = Container
