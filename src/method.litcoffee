# Method - controller of functions

## Class Method

    debug = require('debug')('yang:method')
    # co = require('co') # TODO: should deprecate soon...
    Property = require('./property')

    class Method extends Property
      debug: -> debug @uri, arguments...

      @property 'active',
        get: -> @enumerable or @binding?
      
      get: (pattern) -> switch
        when pattern? then super arguments...
        when @binding? then @do.bind this
        else @content

      set: (value, opts={ suppress: false }) ->
        { suppress, inner, actor } = opts
        @state.prev = @state.value
        @state.value = switch
          when @schema.apply? then @schema.apply value, this, opts
          else value
        ## XXX - we probably don't need to emit anything?
        #@emit 'update', this, actor unless suppress or inner
        return this

### do ()

A convenience wrap to a Property instance that holds a function to
perform a Promise-based execution.

Always returns a Promise.

      do: (input={}) ->
        unless (@binding instanceof Function) or (@content instanceof Function)
          return Promise.reject @error "cannot perform action on a property without function"
        # transaction = true if @root.kind is 'module' and @root.transactable isnt true
        @debug "[do] executing method: #{@name}"
        @debug input
        # @root.transactable = true if transaction
        try
          ctx = @context
          { input } = @schema.input.eval { input }, this, suppress: true
          # first apply schema bound function (if availble), otherwise
          # execute assigned function (if available and not 'missing')
          if @binding?
            @debug "[do] calling bound function with: #{Object.keys(input)}"
            @debug @binding.toString()
            output = @binding.call ctx, input
          else
            @debug "[do] calling assigned function: #{@content.name}"
            output = @content.call @container, input, ctx

          output = await Promise.resolve output
          { output } = @schema.output.eval { output }, this, suppress: true, force: true
          return output
          # return co =>
          #   output = yield Promise.resolve output
          #   { output } = @schema.output.eval { output }, this, suppress: true, force: true
          #   return output
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
