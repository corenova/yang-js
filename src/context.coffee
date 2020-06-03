# Context - control logic binding context

## Context Object
debug = require 'debug'
delegate = require 'delegates'

proto = module.exports = {
  use: (name) ->
    # TODO: below is a bit of a hack...
    return @lookup('feature', name)?.binding
    
  with: (state={}) ->
    @state[k] = v for own k, v of state
    return this
    
  at: (key) ->
    @state.history ?= []
    @state.history.push @node
    @node = @node.in key
    return this

  push: (data, opts={}) ->
    opts = Object.assign opts, @state
    switch @kind
      when 'rpc', 'action'
        @node.do data, opts
      else switch
        when opts.replace is true
          @node.set(data, opts).commit(opts)
        else
          @node.merge(data, opts).commit(opts)
    
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
    
  inspect: -> @toJSON()
  toJSON: -> @node?.valueOf()
}

## Property node delegation
delegate proto, 'node'
  .access 'data' # read/write with validations
  .getter 'schema'
  .getter 'uri'
  .getter 'root'
  .getter 'parent'
  .getter 'name'
  .getter 'kind'
  .getter 'path'
  .getter 'active'
  .getter 'attached' # used for instance-identifier and leafref validations
  .method 'get'
  .method 'error'
  .method 'locate'
  .method 'lookup'
  .method 'find'

delegate proto, 'parent'
  .method 'once'
  .method 'on'
  .method 'off'

## Module delegation
delegate proto, 'root'
  .method 'access'
