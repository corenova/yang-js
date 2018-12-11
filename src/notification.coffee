debug = require('debug')('yang:notification') if process.env.DEBUG?

Container = require './container'

class Notification extends Container

  emit: (event, args...) ->
    super "#{@path}", args...
  
  merge: (value, opts) ->
    return @set value, opts
    
module.exports = Notification
