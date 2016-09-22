# Model - instance of schema-driven data

The `Model` class aggregates [Property](./property.litcoffee)
attachments to provide the *adaptive* and *event-driven* data
interactions.

It is typically not instantiated directly, but is generated as a
result of [Yang::eval](../yang.litcoffee#eval-data-opts) for a YANG
`module` schema.

```javascript
var schema = Yang.parse('module foo { container bar { leaf a { type uint8; } } }');
var model = schema.eval({ 'foo:bar': { a: 7 } });
// model is { 'foo:bar': [Getter/Setter] }
```

The generated `Model` is a hierarchical composition of
[Property](./property.litcoffee) instances. The instance itself uses
`Object.preventExtensions` to ensure no additional properties that are
not known to itself can be added.

It is designed to provide *stand-alone* interactions on a per-module
basis. For flexible management of multiple modules (such as hotplug
modules) and data persistence, please take a look at the
[yang-store](http://github.com/corenova/yang-store) project.

## Dependencies
 
    debug    = require('debug')('yang:model')
    delegate = require 'delegates'
    Stack    = require 'stacktrace-parser'
    Emitter  = require('events').EventEmitter
    Property = require './property'

## Class Model

    class Model extends Property
      
      @Store = {}
      @Property = Property
      
      constructor: ->
        unless this instanceof Model then return new Model arguments...
        super
        
        @state.transactable = false
        @state.queue = []
        @state.features = {}

        Object.setPrototypeOf @state, Emitter.prototype
            
        #@on 'update', -> @save() unless @transactable
        
        # register this instance in the Model class singleton instance
        #@join Model.Store

      delegate @prototype, 'state'
        .method 'emit'
        .access 'features'

### Computed Properties

      @maxTransactions = 100
      maxqueue = @maxTransactions
      enqueue  = (prop, prev) ->
        if @state.queue.length > maxqueue
          throw @error "exceeded max transaction queue of #{maxqueue}, forgot to save()?"
        @state.queue.push { new: prop, old: prev }

      @property 'transactable',
        enumerable: true
        get: -> @state.transactable
        set: (toggle) ->
          return if toggle is @state.transactable
          if toggle is true
            Property::on.call this, 'update', enqueue
          else
            @removeListener 'update', enqueue
            @state.queue.splice(0, @state.queue.length)
          @state.transactable = toggle
          

      valueOf: -> super false

### save

This routine clear the `@updates` transaction queue so that future
[rollback](#rollback) will reset back to this state.

      save: -> @state.queue.splice(0, @state.queue.length) # clear

### rollback

This routine will replay tracked `@updates` in reverse chronological
order (most recent -> oldest) when `@transactable` is set to
`true`. It will restore the Property instance back to the last known
[save](#save-opts) state.

      rollback: ->
        while update = @state.queue.pop()
          update.old.join update.old.parent, suppress: true
        this

### save

This routine triggers a 'commit' event for listeners to handle any
persistence operations. It also clears the `@updates` transaction
queue so that future [rollback](#rollback) will reset back to this state.

      save: -> @emit 'commit', @state.queue.slice(); super

### find (pattern)

This routine enables *cross-model* property search when the `Model` is
joined to another object (such as a datastore). The schema-bound model
restricts *cross-model* property access to only those modules that are
`import` dependencies of the current model instance.

      find: (pattern='.', opts={}) ->
        return super unless @parent?
        
        debug "[#{@name}] find #{pattern}"
        match = super pattern, root: true
        return match if match?.length or opts.root
        
        # here we have a @parent that likely has a collectin of Models
        opts.root = true
        for k, model of @parent.__props__ when k isnt @name
          debug "[#{@name}] looking at #{k}.find"
          try match = model.find pattern, opts
          catch then continue
          return match if match?.length
        return []

### access (model)

This is a unique capability for a Model to be able to access any
arbitrary model present inside the Model.Store.

      access: (model) -> Model.Store[model]

### enable (feature)

      enable: (features...) -> features.forEach (feature) => @require feature

### require (feature)

      require: (feature) ->
        #@features[feature] ?= Yang.System[feature]?.call this
        return @features[feature]

### invoke (path, input)

Executes a `Property` holding a function found at the `path` using the
`input` data.

      invoke: (path, args...) ->
        target = @in(path)
        unless target?
          throw @error "cannot invoke on '#{path}', not found"
        target.invoke args...

### on (event)

The `Model` instance is an `EventEmitter` and you can attach various
event listeners to handle events generated by the `Model`:

event | arguments | description
--- | --- | ---
update | (prop, prev) | fired when an update takes place within the data tree
change | (elems...) | fired when the schema is modified
create | (items...) | fired when one or more `list` element is added
delete | (items...) | fired when one or more `list` element is deleted

It also accepts optional XPATH/YPATH expressions which will *filter*
for granular event subscription to specified events from only the
elements of interest.

The event listeners to the `Model` can handle any customized behavior
such as saving to database, updating read-only state, scheduling
background tasks, etc.

This operation is protected from recursion, where operations by the
`callback` may result in the same `callback` being executed multiple
times due to subsequent events triggered due to changes to the
`Model`. Currently, it will allow the same `callback` to be executed
at most two times.

      on: (event, filters..., callback) ->
        unless callback instanceof Function
          throw new Error "must supply callback function to listen for events"
          
        recursive = (name) ->
          seen = {}
          frames = Stack.parse(new Error().stack)
          for frame, i in frames when ~frame.methodName.indexOf(name)
            { file, lineNumber, column } = frames[i-1]
            callee = "#{file}:#{lineNumber}:#{column}"
            seen[callee] ?= 0
            if ++seen[callee] > 1
              console.warn "detected recursion for '#{callee}'"
              return true 
          return false

        $$$ = (prop, args...) ->
          debug "$$$: check if '#{prop.path}' in '#{filters}'"
          if not filters.length or prop.path.contains filters...
            unless recursive('$$$')
              callback.apply this, [prop].concat args

        @state.on event, $$$

Please refer to [Model Events](../TUTORIAL.md#model-events) section of
the [Getting Started Guide](../TUTORIAL.md) for usage examples.

### in (pattern)

A convenience routine to locate one or more matching Property
instances based on `pattern` (XPATH or YPATH) from this Model.

      in: (pattern) ->
        try props = @find pattern
        return unless props? and props.length
        return switch
          when props.length > 1 then props
          else props[0]

## Export Model Class

    module.exports = Model
