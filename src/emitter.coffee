
class Emitter extends (require 'events').EventEmitter
  constructor: (parent) ->
    Object.defineProperties this,
      parent: value: parent, writable: true
      _events:      writable: true
      _eventsCount: writable: true
    super

  propagate: (events...) -> events.forEach (event) =>
    @on event, -> switch
      when not @parent? then return
      when @parent.__ instanceof Emitter then @parent.__.emit event, arguments...
      when @parent    instanceof Emitter then @parent.emit event, arguments...
      else
        console.debug? "unable to emit '#{event}' from #{@name} -> parent"
        console.debug? "property.emit = #{@parent.__?.emit?}"
        console.debug? "parent.emit   = #{@parent.emit?}"

module.exports = Emitter
