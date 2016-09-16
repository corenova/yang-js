# Emitter - hierarchical event propagation

This `Emitter` class extension to the Node.js standard `EventEmitter`
provides the `propagate()` facility to deal with event propagation in
a hierarchical data tree. It is used in a number of primitive class
objects within the `yang-js` project, such as
[Element](./element.litcoffee), [Property](../property.litcoffee), and
[Model](../model.litcoffee).

You can reference the above classes for more information on how the
`Emitter` class is utilized for propagating state changes up the tree.

## Class Emitter

    Function::property ?= (prop, desc) ->
      Object.defineProperty @prototype, prop, desc

    events = require 'events'

    class Emitter extends events.EventEmitter
      constructor: (events...) ->
        Object.defineProperties this,
          domain:        writable: true
          _events:       writable: true
          _eventsCount:  writable: true
          _maxListeners: writable: true
          _publishes:    value: events
          _subscribers:  value: [], writable: true
          
      emit: (event) ->
        super
        if event in @_publishes ? []
          for x in @_subscribers when x instanceof Emitter
            console.debug? "Emitter.emit '#{event}' to '#{x.constructor.name}'"
            x.emit arguments...

      subscribe: (to) ->
        console.debug? "subscribing '#{@name}' to '#{to.constructor.name}'"
        @_subscribers.push to unless (@_subscribers.some (x) -> x is to)
        return to
        
    module.exports = Emitter
