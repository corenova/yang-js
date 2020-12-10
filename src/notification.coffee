Container = require './container'

class Notification extends Container
  logger: require('debug')('yang:notification')
  merge: (value, opts) -> @set value, opts
    
module.exports = Notification
