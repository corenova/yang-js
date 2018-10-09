{ Property } = require '..'

debug = require('debug')('yang:property:notification') if process.env.DEBUG?

class Notification extends Property

  emit: (event) ->
    super
    unless this is @root
      @root.emit "#{@path}", @content
  
  merge: (value, opts) -> return @set value, opts
    
module.exports = Notification
