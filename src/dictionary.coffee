console.debug ?= console.log if process.env.yang_debug?

# TODO: we should try to eliminate this dependency
synth = require 'data-synth'

class Dictionary

  constructor: (@parent) -> @map = {}

  load: -> synth.copy @map, x for x in arguments when x instanceof Object; return this

  define: (type, key, value, global=false) ->
    exists = @resolve type, key, warn: false
    definition = synth.objectify "#{type}.#{key}", switch
      when not exists?             then value
      when synth.instanceof exists then exists.merge value
      when synth.instanceof value  then value.override exists
      when exists.constructor is Object
        synth.copy exists, value
      else
        throw @error "unable to define #{type}.#{key} due to conflict with existing definition", exists
    synth.copy @map, definition
    return this

  resolve: (type, key, opts={}) ->
    return unless type?

    opts.warn ?= false
    opts.recurse ?= true

    [ prefix..., key ] = (key?.split ':') ? []
    match = switch
      when not key? then @map[type]
      when prefix.length > 0 then @map[prefix[0]]?[type]?[key]
      else @map[type]?[key]
    match ?= @parent?.resolve? arguments... if opts.recurse is true
    unless match?
      console.debug? "[Dictionary:resolve] unable to find #{type}:#{key}" if opts.warn
    return match

  locate: (inside, path) ->
    return unless inside? and typeof path is 'string'
    if /^\//.test path
      console.warn "[Dictionary:locate] absolute-schema-nodeid is not yet supported, ignoring #{path}"
      return
    [ target, rest... ] = path.split '/'

    console.debug? "[Dictionary:locate] locating #{path}"
    if inside.access instanceof Function
      return switch
        when target is '..'
          if (inside.parent.meta 'synth') is 'list'
            @locate inside.parent.parent, rest.join '/'
          else
            @locate inside.parent, rest.join '/'
        when rest.length > 0 then @locate (inside.access target), rest.join '/'
        else inside.access target

    for key, val of inside when val.hasOwnProperty target
      return switch
        when rest.length > 0 then @locate val[target], rest.join '/'
        else val[target]
    console.warn "[Dictionary:locate] unable to find '#{path}' within #{Object.keys inside}"
    return

  error: (msg, context) ->
    res = new Error msg
    res.context = context
    return res

module.exports = Dictionary
