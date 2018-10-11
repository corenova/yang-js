debug = require('debug')('yang:notification') if process.env.DEBUG?

Container = require './container'

class Notification extends Container

  emit: (event) ->
    super
    unless this is @root
      @root.emit "#{@path}", @content
  
  merge: (value, opts) -> return @set value, opts
    
module.exports = Notification
