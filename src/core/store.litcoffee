# Store - server of many Models

The `Store` class aggregates multiple [Model](./model.litcoffee)
instances and provides ability to dynamically [import](#import-model)
additional Models into the Store.

```coffeescript
Yang  = require 'yang-js'
store = new Yang.Store 'some-store-name', models...
store.import model # more model
store.connect data # data source
```

## Class Store

    url = require 'url'
    Yang  = require './yang'      
    Model = require './model'

    class Store extends Model
      
      constructor: (@name, models...) ->
        super (new Model.Property 'data', {}, root: true)
        @import model for model in models
        @on 'connection', (link) ->
          link.emit 'models', models

### import (model)

The `Store` can import additional models to make them available for
access/events/etc. It accepts [Model](./model.litcoffee),
[Yang](./yang.litcoffee), YANG schema text, as well as arbitrary data
object and will *aggregate* their properties under the `@data`
property.

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

### connect (to)

The `Store` can establish data connection to data providers to
load/synchronize data for the models imported into the `Store`.

Currently it accepts a JS object as `source` but the plan is to allow
data provider adapters to be *registered* to the `Store` instance so
that it can operate similar to an ORM with *connect strings*.

      connect: (to) ->
        to = url.parse to
        unless to.protocol?
          data = require to.path
          prop.merge data for prop in @in('/')
          return source
        client = @in "/#{to.protocol}client"
        unless client?
          throw new Error "unable to locate '/#{to.protocol}client' in the Store"
        client.connect to
        .then (data) =>
          prop.merge data for prop in @in('/')
          return data

### in (pattern)

The below is a simple *override* since the root data is contained in
one of its sub-property `@data`.

      in: (pattern) -> Model::in.call @data, pattern
        
## Export Store Class

    module.exports = Store
