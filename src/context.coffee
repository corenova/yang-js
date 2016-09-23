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
  .getter 'name'
  .getter 'kind'
  .getter 'path'
  .getter 'root'

delegate proto, 'content'
  .access 'input'
  .access 'output'
