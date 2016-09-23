# Context - control logic binding context

## Context Object
delegate = require 'delegates'
proto = module.exports = {
  inspect: -> @toJSON()
  toJSON: ->
    property: @property?.valueOf()
  throw: (err) ->
    err = new Error err unless err instanceof Error
    err.ctx = this
    throw err
}

## Property delegation
delegate proto, 'property'
  .method 'get'
  .method 'set'
  .method 'find'
  .access 'content'
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
  .access 'engine'

## Action delegation
delegate proto, 'action'
  .access 'input'
  .access 'output'
