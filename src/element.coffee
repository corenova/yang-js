##
# The below Element class is used during 'yang.transform'
# 
# By default, every new Element created using the provided YANG
# Expression will have implicit event listener and will
# auto-magically update itself whenever the underlying YANG schema
# changes.
##

promise    = require 'promise'
Expression = require './expression'

class Element extends Expression
  
  constructor: (tag, opts={}) ->
    console.debug? "making new Element for '#{tag}'"

    Object.defineProperties this,
      configurable: writable: true, value: true
      enumerable:   writable: true, value: false
      state: writable: true
      set: value: ((val) -> @emit 'set', val).bind this
      get: value: ((xpath) -> switch
        when xpath?
          null
        when @state instanceof Function
          (args...) => new promise (resolve, reject) =>
            @state.apply @parent, [].concat args, resolve, reject
        when @state instanceof Array
          [].concat @state # return a copy array to protect @state
        else @state
      ).bind this

    super

  update: (params={}) ->
    unless params instanceof Object
      throw new Error "must supply params as an 'object'"
      
    @[k] = v for k, v of params when k of this and k isnt 'state'
    switch
      when params.state instanceof Array
        if params.override is true
          @state = params.state
        else
          @state ?= []
          @state = [].concat @state, params.state
      when params.state instanceof Object
        if not @scope? or Object.keys(@scope).length is 0
          @state = params.state
        else
          @state ?= {}
          for own k, v of params.state when k of @scope
            unless @state.hasOwnProperty k
              Object.defineProperty @state, k, @scope[k]
            @state[k] = v
      else
        @state = params.state

    @emit 'updated', @state
    return this

module.exports = Element
