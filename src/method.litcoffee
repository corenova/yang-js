# Method - controller of functions

## Class Method

    Property = require('./property')

    class Method extends Property
      logger: require('debug')('yang:method')

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
        ctx = ctx.with opts, path: @path
        try
          # calling context is the parent node of the method
          input = @schema.input.apply input, this, force: true
          
          # first apply schema bound function (if availble), otherwise
          # execute assigned function (if available and not 'missing')
          if @binding?
            @debug "[do] calling bound function with: #{Object.keys(input)}" if typeof input is 'object'
            @debug @binding.toString()
            output = @binding? ctx, input
          else
            @debug "[do] calling assigned function: #{@data.name}"
            @debug => @value
            @debug => @data
            output = @data.call @parent.data, input, ctx

          output = await output
          { output } = @schema.output.eval { output }, this, force: true
          return output
        catch e
          @debug e
          return Promise.reject(e)

      update: (value, opts) ->
        super value, opts unless value instanceof Property

### toJSON

This call always returns undefined for the Method node.

      toJSON: (key) ->
        value = undefined
        value = "#{@name}": value if key is true
        return value

    module.exports = Method
