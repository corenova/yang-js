# Container - controller of object properties

## Class Container

    Property = require('./property')
    kProp    = Symbol.for('property')

    class Container extends Property

      set: (value, opts) ->
        return this unless value?
        try
          unless value instanceof Function
            if value[kProp] instanceof Property and value[kProp] isnt this
              @debug "[set] cloning existing property for assignment"
              value = clone(value)
            value = Object.create(value) unless Object.isExtensible(value)
          Object.defineProperty value, kProp, configurable: true, value: this

        super

        try
          Object.defineProperty value, kProp, value: this
          Object.defineProperty value, '$', value: @get.bind(this)
          if @schema.nodes.length and @kind isnt 'module'
            for own k of value
              desc = Object.getOwnPropertyDescriptor value, k
              if desc.writable is true and not @schema.locate(k)?
                @debug "[set] hiding non-schema defined property: #{k}"
                Object.defineProperty value, k, enumerable: false

        return this

      merge: (value, opts={ replace: true, suppress: false}) ->

        opts.replace ?= true
        unless @content and @schema.nodes?.length
          opts.replace = false
          return @set value, opts

        # TODO: we shouldn't need this...
        value = value[@name] if value? and value.hasOwnProperty? @name
        return this unless value instanceof Object

        @debug "[merge] merging into existing Object(#{Object.keys(@content)}) for #{@name}"
        # TODO: protect this as a transaction?
        @in(k).merge(v, opts) for own k, v of value when @content.hasOwnProperty k
        
        return this

    module.exports = Container
