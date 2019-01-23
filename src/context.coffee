# Context - control logic binding context

## Context Object
debug = require 'debug'
delegate = require 'delegates'

proto = module.exports = {
  inspect: -> @toJSON()
  use: (name) ->
    # TODO: below is a bit of a hack...
    return @schema.lookup('feature', name)?.binding
  toJSON: -> @property?.valueOf()
  throw: (err) ->
    err = new Error err unless err instanceof Error
    err.context = this
    throw err
  with: (state={}) -> @state[k] = v for own k, v of state; this
  defer: (data) ->
    @property.debug "deferring '#{@kind}:#{@name}' until update at #{@root.name}"
    @root.once 'update', =>
      @property.debug "applying deferred data (#{typeof data}) into #{@path}"
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
  log: (topic, args...) ->
    @root.emit('log', topic, args, @property)
}

## Property delegation
delegate proto, 'property'
  .method 'get'
  .method 'find'
  .method 'in'
  .method 'once'
  .method 'on'
  .method 'error'
  .access 'content' # read/write with validations
  .getter 'schema'
  .getter 'container'
  .getter 'parent'
  .getter 'name'
  .getter 'kind'
  .getter 'path'
  .getter 'uri'
  .getter 'root'
  .getter 'attached'

delegate proto, 'schema'
  .method 'locate'

## State delegation
delegate proto, 'state'
  .access 'value' # read/write w/o validations

## Module delegation
delegate proto, 'root'
  .method 'access'
  .getter 'store'
