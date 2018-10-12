# Method - controller of functions

## Class Method

    co       = require('co')
    Property = require('./property')
    kProp    = Symbol.for('property')

    class Method extends Property

      get: (pattern) -> switch
        when pattern? then super
        when @binding? then @do.bind this
        else @content

      set: (value, opts={ suppress: false }) ->
        @state.prev = @state.value
        @state.value = switch
          when @schema.apply? then @schema.apply value, @context.with(opts)
          else value
        @emit 'update', this unless opts.suppress
        return this

### do ()

A convenience wrap to a Property instance that holds a function to
perform a Promise-based execution.

Always returns a Promise.

      do: (input={}) ->
        unless (@binding instanceof Function) or (@content instanceof Function)
          return Promise.reject @error "cannot perform action on a property without function"
        transaction = true if @root.kind is 'module' and @root.transactable isnt true
        @debug "[do] executing method: #{@name}"
        @debug input
        @root.transactable = true if transaction
        try
          ctx = @context
          ctx.state[kProp] = this
          @schema.input?.eval  ctx.state, {}
          @schema.output?.eval ctx.state, {}
          ctx.input = input
          # first apply schema bound function (if availble), otherwise
          # execute assigned function (if available and not 'missing')
          if @binding?
            @debug "[do] calling bound function with: #{Object.keys(input)}"
            @debug @binding.toString()
            res = @binding.call ctx, input
            ctx.output ?= res
          else
            @debug "[do] calling assigned function: #{@content.name}"
            ctx.output = @content.call @container, input
          return co =>
            @debug "[do] evaluating output schema"
            ctx.output = yield Promise.resolve ctx.output
            @debug "[do] finish setting output"
            @emit 'done', ctx
            if transaction
              @root.save()
              @root.transactable = false
            return ctx.output
        catch e
          @debug e
          if transaction
            @root.rollback()
            @root.transactable = false
          return Promise.reject e

    module.exports = Method
