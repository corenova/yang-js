# Context - control logic binding context

## Context Object
debug = require('debug')('yang:context')
delegate = require 'delegates'

proto = module.exports = {
  use: (name) ->
    # TODO: below is a bit of a hack...
    return @lookup('feature', name)?.binding

  with: (options...) ->
    ctx = Object.create(this)
    ctx.opts = Object.assign {}, @opts, options...
    Object.preventExtensions ctx
    return ctx
    
  at: (key) ->
    node = @node.in key
    unless node? then throw @error "unable to access #{key}"
    return node.context.with @opts

  push: (data) ->
    return @node.do(data, @opts) if @kind in [ 'rpc', 'action' ]

    opts = Object.assign {}, @opts # make a copy
    @node.merge(data, opts)
    diff = @node.change if @node.changed
    try await @node.commit(opts)
    catch err then throw @error err
    return diff

  # convenience function for replace (set operation)
  replace: (data) -> @with( replace: true ).push(data)

  set:   (data) -> @node.set(data, Object.assign {}, @opts)
  merge: (data) -> @node.merge(data, Object.assign {}, @opts)
    
  after: (timeout, max) ->
    timeout = parseInt(timeout) || 100
    max = parseInt(max) || 5000
    new Promise (resolve) -> 
      setTimeout (-> resolve(Math.round(Math.min(max, timeout * 1.5)))), timeout

  logDebug: -> @log 'debug', arguments...
  logInfo:  -> @log 'info', arguments...
  logWarn:  -> @log 'warn', arguments...
  logError: -> @log 'error', @error arguments...
    
  log: (topic, args...) ->
    @root.emit('log', topic, args, this)
}

## Property node delegation
delegate proto, 'node'
  .access 'data' # read/write with validations
  .getter 'prior'
  .getter 'value'
  
  .getter 'root'
  .getter 'parent'
  .getter 'schema'
  
  .getter 'uri'
  .getter 'name'
  .getter 'kind'
  .getter 'path'
  .getter 'active'
  .getter 'attached' # used for instance-identifier and leafref validations
  .getter 'changed'  # boolean
  .getter 'changes'  # Set of changed properties
  .getter 'change'   # Object
  
  .method 'get'
  .method 'commit'
  .method 'revert'
  .method 'error'
  .method 'locate'
  .method 'lookup'
  .method 'find'
  .method 'inspect'
  .method 'toJSON'

## Module delegation
delegate proto, 'root'
  .method 'access'
