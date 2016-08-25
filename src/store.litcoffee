# Store - server of many Models

The `Store` class is where the [Model](./model.litcoffee) instances
are collected and managed.

## Class Store

    Yang  = require './yang'      
    Model = require './model'
    Expression = require './expression'

    class Store extends Model

      constructor: (name, models...) ->
        super # become Model
        
        @import model for model in models
        
        models = models.filter (model) =>
          return false unless model instanceof Model and model.in('/').name?
          name = model.in('/').name
          if name of this
            console.warn "unable to use '#{name}' Model due to conflict with existing prototype method"
            false
          else true

## Instance-level methods

      import: (model, data) ->
        model = switch
          when model instanceof Model
            model.in('/').merge data if data?
            model
          when model instanceof Yang    then model.eval data
          when typeof model is 'string' then Yang.parse(model).eval data
          else Yang.compose(model).eval data

        props = model.in('/').props
        
        @emit 'import', model
        return model
    
      connect: (source) ->
        for own k, v of this

        
      on: ->
        
        
### in (pattern)

A convenience routine to locate one or more matching Property
instances based on `pattern` (XPATH or YPATH) from this Store across
various Models.

      in: (pattern) ->
        try props = @__.find(pattern).props
        catch then return
        return switch
          when not props.length then null
          when props.length > 1 then props
          else props[0]

## Export Store Class

    module.exports = Store
