# Context - control logic binding context

## Context Object
debug = require('debug')('yang:context') if process.env.DEBUG?
delegate = require 'delegates'
proto = module.exports = {
  inspect: -> @toJSON()
  toJSON: -> @property?.valueOf()
  throw: (err) ->
    err = new Error err unless err instanceof Error
    err.ctx = this
    throw err
  state: {}
  with: (obj={}) -> @state[k] = v for own k, v of obj; this
  defer: (data) ->
    debug? "deferring '#{@path}' until update"
    @once? 'update', =>
      debug? "applying deferred data into #{@path}"
      @set data
    return data
  debug: -> debug? arguments...
}

## Property delegation
delegate proto, 'property'
  .method 'get'
  .method 'set'
  .method 'merge'
  .method 'create'
  .method 'find'
  .access 'content'
  .getter 'container'
  .getter 'schema'
  .getter 'name'
  .getter 'kind'
  .getter 'path'
  .getter 'root'

## Module delegation
delegate proto, 'root'
  .method 'access'
  .method 'enable'
  .method 'disable'
  .method 'once'
  .method 'on'
  .method 'in'
  .access 'engine'

## Action delegation
delegate proto, 'action'
  .access 'input'
  .access 'output'
