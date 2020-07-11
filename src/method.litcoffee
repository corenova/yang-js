# Method - controller of functions

## Class Method

    debug = require('debug')('yang:method')
    Container = require('./container')

    class Method extends Container
      debug: -> debug @uri, arguments...

      @property 'value',
        get: -> @state.value ? @do.bind this

      get: (pattern) -> switch
        when pattern? then super arguments...
        when @binding? then @do.bind this
        else @data

### do ()

A convenience wrap to a Property instance that holds a function to
perform a Promise-based execution.

Always returns a Promise.

      do: (input={}, opts={}) ->
        unless (@binding instanceof Function) or (@data instanceof Function)
          return Promise.reject @error "cannot perform action on a property without function"
        @debug "[do] executing method: #{@name}"
        @debug input
        ctx = @parent?.context ? @context
        try
          # calling context is the parent node of the method
          input = @schema.input.apply input, this, suppress: true
          # { input } = @schema.input.eval { input }, this, suppress: true
          
          # first apply schema bound function (if availble), otherwise
          # execute assigned function (if available and not 'missing')
          if @binding?
            @debug "[do] calling bound function with: #{Object.keys(input)}"
            @debug @binding.toString()
            output = @binding? ctx.with(opts), input
          else
            @debug "[do] calling assigned function: #{@data.name}"
            output = @data.call @parent.data, input, ctx.with(opts)

          output = await Promise.resolve output
          output = @schema.output.apply output, this, suppress: true, force: true
          # { output } = @schema.output.eval { output }, this, suppress: true, force: true
          return output
        catch e
          @debug e
          return Promise.reject e

### toJSON

This call always returns undefined for the Method node.

      toJSON: (key) ->
        value = undefined
        value = "#{@name}": value if key is true
        return value

    module.exports = Method
