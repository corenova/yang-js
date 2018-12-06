# Context - control logic binding context

## Context Object
debug = require('debug')('yang:context') # if process.env.DEBUG?
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
    debug? "deferring '#{@kind}:#{@name}' until update at #{@root.name}"
    debug? data
    @root.once 'update', =>
      debug? "applying deferred data (#{typeof data}) into #{@path}"
      debug? data
      @content = data
    return data
  debug: -> debug? arguments...
}

## Property delegation
delegate proto, 'property'
  .method 'get'
  .method 'find'
  .method 'in'
  .method 'once'
  .method 'on'
  .access 'content' # read/write with validations
  .getter 'schema'
  .getter 'container'
  .getter 'parent'
  .getter 'name'
  .getter 'kind'
  .getter 'path'
  .getter 'root'
  .getter 'attached'

## State delegation
delegate proto, 'state'
  .access 'input'
  .access 'output'
  .access 'value' # read/write w/o validations

## Module delegation
delegate proto, 'root'
  .method 'access'
  .getter 'store'
