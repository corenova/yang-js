debug = require('debug')('yang:notification')
Container = require './container'

class Notification extends Container
  debug: -> debug @uri, arguments...
  emit: (event, args...) ->
    super "#{@path}", args...
  merge: (value, opts) ->
    return @set value, opts
    
module.exports = Notification
