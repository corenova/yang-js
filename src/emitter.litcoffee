# Emitter - hierarchical event propagation

This `Emitter` class extension to the Node.js standard `EventEmitter`
provides the `propagate()` facility to deal with event propagation in
a hierarchical data tree. It is used in a number of primitive class
objects within the `yang-js` project, such as
[Element](./element.litcoffee), [Property](./property.litcoffee), and
[Model](./model.litcoffee).

You can reference the above classes for more information on how the
`Emitter` class is utilized for propagating state changes up the tree.

## Class Emitter

    events = require 'events'

    class Emitter extends events.EventEmitter
      constructor: (parent) ->
        Object.defineProperties this,
          parent: value: parent, writable: true
          domain: writable: true
          _events:       writable: true
          _eventsCount:  writable: true
          _maxListeners: writable: true
        super

      propagate: (events...) ->
        propagate = (event, args...) ->
          for x in [ @parent.__, @parent ] when x instanceof Emitter
            x.emit event, args... 
        events.forEach (event) => @on event, propagate.bind this, event

    module.exports = Emitter
