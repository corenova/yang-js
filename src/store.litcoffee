# Store - server of many Models

The `Store` class is where the [Model](./model.litcoffee) instances
are collected and managed.

## Class Store

    Yang  = require './yang'      
    Model = require './model'

    class Store extends Model
      constructor: (@name, models...) ->
        super (new Model.Property 'data', {}, root: true)
        @import model for model in models

## Instance-level methods

      import: (model, data) ->
        model = switch
          when model instanceof Model
            prop.merge data for prop in model.in('/') if data?
            model
          when model instanceof Yang    then model.eval(data)
          when typeof model is 'string' then Yang.parse(model).eval(data)
          else Yang.compose(model).eval(data)

        for k, prop of model.__props__
          console.info "[#{@name}] importing '#{k}' from model to the store"
          do (k) => Object.defineProperty model, k, get: (-> @[k] ).bind @data
          prop.join @data
        
        @emit 'import', model
        return model

      # this will be how future data provider connect string will be handled
      connect: (source) -> switch
        when source.constructor is Object
          prop.merge source for prop in @in('/')
          console.log @__props__.data.valueOf()

      in: (pattern) -> Model::in.call @data, pattern
        
## Export Store Class

    module.exports = Store
