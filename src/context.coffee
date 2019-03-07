# Context - control logic binding context

## Context Object
debug = require 'debug'
delegate = require 'delegates'

proto = module.exports = {
  inspect: -> @toJSON()
  toJSON: -> @property?.valueOf()
  use: (name) ->
    # TODO: below is a bit of a hack...
    return @lookup('feature', name)?.binding
  throw: (err) ->
    err = new Error err unless err instanceof Error
    err.context = this
    throw err
  with: (state={}) -> @state[k] = v for own k, v of state; this
  defer: (data) ->
    @property.debug "deferring '#{@kind}:#{@name}' until update at #{@root.name}"
    console.warn(@root)
    @root.once 'update', =>
      @property.debug "applying deferred data (#{typeof data})"
      @content = data
    return data
  after: (timeout, max) ->
    timeout = parseInt(timeout) || 100
    max = parseInt(max) || 5000
    new Promise (resolve) -> 
      setTimeout (-> resolve(Math.round(Math.min(max, timeout * 1.5)))), timeout

  debug: -> @log 'debug', arguments...
  info:  -> @log 'info', arguments...
  warn:  -> @log 'warn', arguments...
  error: -> @log 'error', @property.error arguments...
  log: (topic, args...) ->
    @root.emit('log', topic, args, this)
}

## Property delegation
delegate proto, 'property'
  .access 'content' # read/write with validations
  .getter 'container'
  .getter 'schema'
  .getter 'uri'
  .getter 'root'
  .getter 'parent'
  .getter 'name'
  .getter 'kind'
  .getter 'path'
  .getter 'attached' # used for instance-identifier and leafref validations
  .method 'locate'
  .method 'lookup'
  .method 'in'
  .method 'get'

delegate proto, 'parent'
  .method 'once'
  .method 'on'
  .method 'set'
  .method 'merge'

## Module delegation
delegate proto, 'root'
  .getter 'store'
  .method 'access'
