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

Below are list of properties available to every instance of `Model`
(it also inherits properties from [Property](./property.litcoffee)):

property | type | mapping | description
--- | --- | --- | ---
transactable | boolean | computed | getter/setter for `state.transactable`
engine | Emitter | access(state) | holds runtime features

## Dependencies
 
    debug    = require('debug')('yang:model') if process.env.DEBUG?
    delegate = require 'delegates'
    clone    = require 'clone'
    Stack    = require 'stacktrace-parser'
    Emitter  = require('events').EventEmitter
    Property = require './property'
    XPath    = require './xpath'

## Class Model

    class Model extends Property
      
      @Store   = {}
      @Property = Property
      
      constructor: ->
        unless this instanceof Model then return new Model arguments...
        super
        
        @state.transactable = false
        @state.maxTransactions = 100
        @state.queue = []
        @state.engine = new Emitter # <-- should eventually be a singleton instance
        @state.engine.__ = this
        Object.setPrototypeOf @state, Emitter.prototype

        # listen for schema changes and adapt!
        @schema.on 'change', (elem) =>
          debug? "[#{@name}:adaptive] detected schema change at #{elem.datapath}"
          try props = @find(elem.datapath)
          catch then props = []
          props.forEach (prop) -> prop.set prop.content, force: true

        # register this instance in the Model class singleton instance
        @join Model.Store, replace: true
        debug? "created a new YANG Model: #{@name}"

      delegate @prototype, 'state'
        .method 'emit'
        .method 'once'
        .access 'engine'
        .getter 'queue'

### Computed Properties

      enqueue = (prop) ->
        if @queue.length > @maxTransactions
          throw @error "exceeded max transaction queue of #{@maxTransactions}, forgot to save()?"
        @queue.push { target: prop, value: prop.state.prev }

      @property 'transactable',
        enumerable: true
        get: -> @state.transactable
        set: (toggle) ->
          return if toggle is @state.transactable
          if toggle is true
            @state.on 'update', enqueue
          else
            @state.removeListener 'update', enqueue
            @state.queue.splice(0, @state.queue.length)
          @state.transactable = toggle

### access (model)

This is a unique capability for a Model to be able to access any
other arbitrary model present inside the Model.Store.

      access: (model) ->
        try Model.Store[model].__
        catch e then throw @error "unable to locate '#{model}' instance in the Store"

### enable (feature)

This routine will enable a given `feature` 

      enable: (feature, controller) ->
        @engine[feature] = controller if controller?
        unless @engine.hasOwnProperty feature
          throw @error "unable to enable unknown feature '#{feature}'"
        @engine.emit "enable:#{feature}", @engine[feature]
        return this

### save

This routine triggers a 'commit' event for listeners to handle any
persistence operations. It also clears the `@state.queue` transaction
queue so that future [rollback](#rollback) will reset back to this
state.

      save: ->
        debug? "[save] trigger commit and clear queue"
        @emit 'commit', @state.queue.slice();
        @state.queue.splice(0, @state.queue.length)
        return this

### rollback

This routine will replay tracked `@state.queue` in reverse chronological
order (most recent -> oldest) when `@transactable` is set to
`true`. It will restore the Property instance back to the last known
[save](#save-opts) state.

      rollback: ->
        while change = @state.queue.pop()
          change.target.set change.value, suppress: true
        return this

### on (event)

The `Model` instance registers `@state` as an `EventEmitter` and you
can attach various event listeners to handle events generated by the
`Model`:

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
at most two times within the same execution stack.

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

        ctx = @context
        $$$ = (prop, args...) ->
          debug? "$$$: check if '#{prop.path}' in '#{filters}'"
          if not filters.length or prop.path.contains filters...
            unless recursive('$$$')
              callback.apply ctx, [prop].concat args

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

## Prototype Overrides

### toJSON

Calls `Property.toJSON` with `tag = false`.

      toJSON: -> super false

### set

Calls `Property.set` with a *clone* of the data being passed in. When
data is loaded at the Model, we need to handle any intermediary errors
due to incomplete data mappings while values are being set on the
tree.

      set: (value, opts) ->
        value = {} unless @schema.nodes.length
        super clone(value), opts

### find (pattern)

This routine enables *cross-model* property search when the `Model` is
joined to another object (such as a datastore). The schema-bound model
restricts *cross-model* property access to only those modules that are
`import` dependencies of the current model instance.

      find: (pattern='.', opts={}) ->
        return super unless @container?
        
        debug? "[#{@name}:find] match #{pattern}"
        try match = super pattern, root: true
        catch e then match = []
        return match if match.length or opts.root

        xpath = switch
          when pattern instanceof XPath then pattern
          else XPath.parse pattern, @schema

        [ target ] = xpath.xpath.tag.split(':')
        return [] if target is @name
        
        debug? "[#{@name}:find] locate #{target} and apply #{xpath}"
        opts.root = true
        try return @access(target).find xpath, opts 
        try return @schema.lookup('module', target).eval(@content).find xpath, opts
        return []

### invoke (path, input)

Executes a [Property](./property.litcoffee) holding a function found
at the `path` using the `input` data.

      invoke: (path, args...) ->
        target = @in(path)
        unless target?
          throw @error "cannot invoke on '#{path}', not found"
        target.invoke args...
            
## Export Model Class

    module.exports = Model
